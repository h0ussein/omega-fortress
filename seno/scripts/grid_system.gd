extends Node2D

# Grid properties
@export var grid_width: int = 50
@export var grid_height: int = 50
@export var cell_size: int = 64
@export var show_grid: bool = false
@export var green_zone_size: int = 20
@export var green_zone_y_offset: int = 8

# Grid cell types: 0 = empty, 1 = barrier, 2 = base, 3 = hero, 4 = enemy
var grid_cells = {}

# Grid zones: 0 = red zone (outside), 1 = green zone (around base)
var grid_zones = {}

# Visual properties
@export var grid_color: Color = Color(0.2, 0.2, 0.2, 0.4)
@export var green_zone_color: Color = Color(0.0, 0.8, 0.0, 0.2)
@export var red_zone_color: Color = Color(0.8, 0.0, 0.0, 0.2)

# Base position
var base_center: Vector2 = Vector2.ZERO

# Path marker position (will be set by the barrier manager)
var path_marker_position: Vector2 = Vector2.ZERO

# Visibility states
var buying_hero: bool = false
var moving_hero: bool = false
var placing_barrier: bool = false

# Pathfinding optimization
var path_cache = {}  # Cache for paths
var path_cache_timestamps = {}  # Track when paths were cached
var grid_changed: bool = true  # Flag to track grid changes, start as true

# Pathfinding performance
var max_pathfinding_time_ms: int = 100  # Maximum time to spend on pathfinding

# Invalid placement visualization
var invalid_placement_pos = null

# Debug visualization - removed show_debug_path and path_color
var debug_path_to_draw = []  # Store the last checked path for visualization
var show_debug_path = false  # Default to false to hide the blue line

# Signals
signal grid_updated

func _ready():
	# Position the grid so the base is at (0,0) in world coordinates
	position = Vector2(-grid_width * cell_size / 2, -grid_height * cell_size / 2)

	initialize_grid()
	place_base_in_center()
	setup_zones()


func _draw():
	# Only draw the grid if one of the three conditions is met
	if buying_hero or moving_hero or placing_barrier:
		# Draw zone backgrounds first
		for x in range(grid_width):
			for y in range(grid_height):
				var pos = Vector2(x, y)
				var rect = Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
				
				if grid_zones.get(str(pos), 0) == 1:
					# Green zone
					draw_rect(rect, green_zone_color, true)
				else:
					# Red zone
					draw_rect(rect, red_zone_color, true)
		
		# Draw invalid placement indicator
		if invalid_placement_pos != null and placing_barrier:
			var rect = Rect2(invalid_placement_pos.x * cell_size, invalid_placement_pos.y * cell_size, cell_size, cell_size)
			draw_rect(rect, Color(1, 0, 0, 0.5), true)  # Red highlight
		
		# Draw grid lines
		for x in range(grid_width + 1):
			var start = Vector2(x * cell_size, 0)
			var end = Vector2(x * cell_size, grid_height * cell_size)
			draw_line(start, end, grid_color)
		
		for y in range(grid_height + 1):
			var start = Vector2(0, y * cell_size)
			var end = Vector2(grid_width * cell_size, y * cell_size)
			draw_line(start, end, grid_color)
		
		# Removed the debug path drawing code

# Set path marker position
func set_path_marker_position(pos: Vector2):
	path_marker_position = pos
	grid_changed = true  # Mark grid as changed when path marker is set
	print("Grid System: Path marker position set to " + str(path_marker_position))

# Set invalid placement position for visualization
func set_invalid_placement(pos: Vector2):
	invalid_placement_pos = pos
	queue_redraw()

# Clear invalid placement visualization
func clear_invalid_placement():
	invalid_placement_pos = null
	queue_redraw()

# Set grid visibility for buying hero
func set_buying_hero(value: bool):
	buying_hero = value
	queue_redraw()

# Set grid visibility for moving hero
func set_moving_hero(value: bool):
	moving_hero = value
	queue_redraw()

# Set grid visibility for placing barrier
func set_placing_barrier(value: bool):
	placing_barrier = value
	queue_redraw()

func initialize_grid():
	grid_cells.clear()
	grid_zones.clear()
	path_cache.clear()
	path_cache_timestamps.clear()

	# Initialize empty grid
	for x in range(grid_width):
		for y in range(grid_height):
			grid_cells[str(Vector2(x, y))] = 0
			grid_zones[str(Vector2(x, y))] = 0  # Default to red zone


func place_base_in_center():
	# Calculate exact center of grid
	var center_x = int(grid_width / 2) - 1
	var center_y = int(grid_height / 2) - 1
	base_center = Vector2(center_x, center_y)

	# Mark 4 cells for base (2x2)
	for x in range(2):
		for y in range(2):
			var pos = Vector2(center_x + x, center_y + y)
			grid_cells[str(pos)] = 2  # 2 = base


func setup_zones():
	# Calculate the bounds of the square green zone
	var half_size = int(green_zone_size / 2)

	# Apply offset to center the green zone horizontally around the base
	var min_x = max(0, base_center.x - half_size)
	var max_x = min(grid_width - 1, base_center.x + half_size + 1)  # +1 to include the base

	# Apply Y offset to move the green zone down
	# Make the green zone extend more downward than upward
	var min_y = max(0, base_center.y - (half_size / 2))  # Less space above the base
	var max_y = min(grid_height - 1, base_center.y + half_size + green_zone_y_offset)  # More space below the base


	# Clear all zones first
	for x in range(grid_width):
		for y in range(grid_height):
			var pos = Vector2(x, y)
			grid_zones[str(pos)] = 0  # Reset to red zone

	# Set up green zone with the new bounds
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var pos = Vector2(x, y)
			grid_zones[str(pos)] = 1  # Green zone

	# Make sure the base itself is always in the green zone
	for x in range(2):
		for y in range(2):
			var pos = Vector2(base_center.x + x, base_center.y + y)
			grid_zones[str(pos)] = 1  # Green zone

	queue_redraw()

# Convert world position to grid coordinates
func world_to_grid(world_pos: Vector2) -> Vector2:
	var x = int((world_pos.x - position.x) / cell_size)
	var y = int((world_pos.y - position.y) / cell_size)
	return Vector2(x, y)

# Convert grid coordinates to world position (cell center)
func grid_to_world(grid_pos: Vector2) -> Vector2:
	var x = position.x + grid_pos.x * cell_size + cell_size / 2
	var y = position.y + grid_pos.y * cell_size + cell_size / 2
	return Vector2(x, y)

# Check if a cell is within grid bounds
func is_within_bounds(grid_pos: Vector2) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_width and grid_pos.y >= 0 and grid_pos.y < grid_height

# Check if a cell is empty
func is_cell_empty(grid_pos: Vector2) -> bool:
	if not is_within_bounds(grid_pos):
		return false
	return grid_cells.get(str(grid_pos), 0) == 0

# Check if a cell is in the green zone
func is_in_green_zone(grid_pos: Vector2) -> bool:
	if not is_within_bounds(grid_pos):
		return false

	var is_green = grid_zones.get(str(grid_pos), 0) == 1
	return is_green

# Get all cells that are part of the base
func get_base_cells() -> Array:
	var base_cells = []

	for x in range(2):
		for y in range(2):
			base_cells.append(Vector2(base_center.x + x, base_center.y + y))

	return base_cells

# Get all cells that are adjacent to the base
func get_cells_adjacent_to_base() -> Array:
	var adjacent_cells = []

	# Base is 2x2, check all cells around the perimeter
	# Top row
	for x in range(base_center.x - 1, base_center.x + 3):
		adjacent_cells.append(Vector2(x, base_center.y - 1))

	# Bottom row
	for x in range(base_center.x - 1, base_center.x + 3):
		adjacent_cells.append(Vector2(x, base_center.y + 2))

	# Left column (excluding corners which are already added)
	for y in range(base_center.y, base_center.y + 2):
		adjacent_cells.append(Vector2(base_center.x - 1, y))

	# Right column (excluding corners which are already added)
	for y in range(base_center.y, base_center.y + 2):
		adjacent_cells.append(Vector2(base_center.x + 2, y))

	# Filter out cells that are outside the grid bounds
	var valid_cells = []
	for cell in adjacent_cells:
		if is_within_bounds(cell):
			valid_cells.append(cell)

	return valid_cells

# Get the path marker position from the scene
func get_path_marker_position() -> Vector2:
	# Only use the Marker_path for path checking
	var path_marker = get_node_or_null("/root/Node2D_main/Marker_path")
	
	if not path_marker:
		print("Grid System: ERROR - Marker_path not found! Cannot check path.")
		return Vector2.ZERO
	
	# Use the Marker_path position for path checking
	return world_to_grid(path_marker.global_position)

# Check if placing a barrier at the given position would block all paths to the base
# This uses a flood fill algorithm to check if the base is reachable from the path marker
func would_block_all_paths(grid_pos: Vector2) -> bool:
	# Get the path marker position
	var path_check_pos = get_path_marker_position()
	
	if path_check_pos == Vector2.ZERO:
		return false  # Allow placement if we can't check
		
	# Debug output
	print("Checking if placing barrier at " + str(grid_pos) + " would block all paths")
	print("Path check using Marker_path position: " + str(path_check_pos))

	# Create a temporary grid for the flood fill
	var temp_grid = {}
	for key in grid_cells:
		temp_grid[key] = grid_cells[key]

	# Place the barrier in the temporary grid
	temp_grid[str(grid_pos)] = 1  # 1 = barrier

	# Get all cells adjacent to the base
	var base_adjacent_cells = get_cells_adjacent_to_base()
	print("Base adjacent cells: " + str(base_adjacent_cells))

	# Check if any base adjacent cell is reachable from the path marker
	var queue = [path_check_pos]
	var visited = {}

	while queue.size() > 0:
		var current = queue.pop_front()
		var current_str = str(current)
		
		# Skip if already visited
		if visited.has(current_str):
			continue
		
		# Mark as visited
		visited[current_str] = true
		
		# Check if this is a base adjacent cell
		for base_adj in base_adjacent_cells:
			if current == base_adj:
				# Found a path to a base adjacent cell
				# Store the path for visualization but don't show it
				var path = reconstruct_path_from_visited(visited, path_check_pos, current)
				debug_path_to_draw = path
				show_debug_path = false  # Don't show the debug path
				queue_redraw()
				print("Path found! Path length: " + str(path.size()))
				return false
		
		# Check neighbors (4 directions)
		var directions = [
			Vector2(1, 0),   # Right
			Vector2(-1, 0),  # Left
			Vector2(0, 1),   # Down
			Vector2(0, -1)   # Up
		]
		
		for dir in directions:
			var neighbor = current + dir
			var neighbor_str = str(neighbor)
			
			# Skip if not within bounds
			if not is_within_bounds(neighbor):
				continue
			
			# Skip if already visited
			if visited.has(neighbor_str):
				continue
			
			# Skip if it's a barrier
			if temp_grid.get(neighbor_str, 0) == 1:
				continue
			
			# Add to queue
			queue.append(neighbor)

	# If we get here, no path was found
	print("No path found! Placement would block all paths.")
	show_debug_path = false  # Don't show the debug path
	queue_redraw()
	return true

# Reconstruct path from visited nodes (for visualization)
func reconstruct_path_from_visited(visited: Dictionary, start: Vector2, end: Vector2) -> Array:
	var path = [end]
	var current = end

	# Simple BFS to find the path
	var queue = [current]
	var path_visited = {}
	var came_from = {}

	path_visited[str(current)] = true

	while queue.size() > 0:
		current = queue.pop_front()
		
		if current == start:
			break
		
		var directions = [
			Vector2(1, 0),   # Right
			Vector2(-1, 0),  # Left
			Vector2(0, 1),   # Down
			Vector2(0, -1)   # Up
		]
		
		for dir in directions:
			var neighbor = current + dir
			var neighbor_str = str(neighbor)
			
			if visited.has(neighbor_str) and not path_visited.has(neighbor_str):
				path_visited[neighbor_str] = true
				came_from[neighbor_str] = current
				queue.append(neighbor)

	# Reconstruct the path
	current = start
	path = [current]

	while current != end:
		var current_str = str(current)
		if not came_from.has(current_str):
			break
		
		current = came_from[current_str]
		path.append(current)

	return path

# Place a barrier
func place_barrier(grid_pos: Vector2) -> bool:
	if not is_within_bounds(grid_pos):
		return false

	# Check if in green zone
	if not is_in_green_zone(grid_pos):
		return false

	# Check if cell is empty
	var cell_content = grid_cells.get(str(grid_pos), 0)
	if cell_content != 0:
		var content_type = ""
		match cell_content:
			1: content_type = "barrier"
			2: content_type = "base"
			3: content_type = "hero"
			4: content_type = "enemy"
		return false

	# Place barrier
	grid_cells[str(grid_pos)] = 1  # 1 = barrier

	# Mark grid as changed and clear path cache completely
	grid_changed = true
	path_cache.clear()
	path_cache_timestamps.clear()

	emit_signal("grid_updated")
	queue_redraw()
	return true

# Remove a barrier
func remove_barrier(grid_pos: Vector2) -> bool:
	if not is_within_bounds(grid_pos):
		return false

	if grid_cells.get(str(grid_pos), 0) == 1:
		grid_cells[str(grid_pos)] = 0  # 0 = empty
		
		# Mark grid as changed and clear path cache completely
		grid_changed = true
		path_cache.clear()
		path_cache_timestamps.clear()
		
		emit_signal("grid_updated")
		queue_redraw()
		return true

	return false

# Register a hero on the grid
func register_hero(hero: Node2D, grid_pos: Vector2) -> bool:
	if not is_within_bounds(grid_pos):
		return false

	# Check if in green zone
	if not is_in_green_zone(grid_pos):
		return false

	if is_cell_empty(grid_pos):
		grid_cells[str(grid_pos)] = 3  # 3 = hero
		
		# Mark grid as changed and clear path cache
		grid_changed = true
		path_cache.clear()
		path_cache_timestamps.clear()
		
		return true

	return false

# Register an enemy on the grid
func register_enemy(enemy: Node2D, grid_pos: Vector2) -> bool:
	if not is_within_bounds(grid_pos):
		return false

	if is_cell_empty(grid_pos):
		grid_cells[str(grid_pos)] = 4  # 4 = enemy
		return true

	return false

# Unregister a hero from the grid
func unregister_hero(grid_pos: Vector2):
	if is_within_bounds(grid_pos):
		if grid_cells.get(str(grid_pos), 0) == 3:
			grid_cells[str(grid_pos)] = 0  # 0 = empty
			
			# Mark grid as changed and clear path cache
			grid_changed = true
			path_cache.clear()
			path_cache_timestamps.clear()

# Unregister an enemy from the grid
func unregister_enemy(grid_pos: Vector2):
	if is_within_bounds(grid_pos):
		if grid_cells.get(str(grid_pos), 0) == 4:
			grid_cells[str(grid_pos)] = 0  # 0 = empty

# Move a hero to a new position
func move_hero(from_pos: Vector2, to_pos: Vector2) -> bool:
	if not is_within_bounds(to_pos):
		return false

	# Check if in green zone
	if not is_in_green_zone(to_pos):
		return false

	if is_cell_empty(to_pos):
		unregister_hero(from_pos)
		grid_cells[str(to_pos)] = 3  # 3 = hero
		
		# Mark grid as changed and clear path cache
		grid_changed = true
		path_cache.clear()
		path_cache_timestamps.clear()
		
		return true

	return false

# Find path for an enemy - using the enemy's actual position as the starting point
func find_path_for_enemy(enemy: Node2D) -> Array:
	if not enemy.target:
		return []

	# Use the enemy's actual position as the starting point
	var start_pos = world_to_grid(enemy.global_position)
	var end_pos = world_to_grid(enemy.target.global_position)

	# Special case: If start and end are the same cell, return empty path
	if start_pos == end_pos:
		return []
		
	# Special case: If start and end are adjacent, return direct path
	if start_pos.distance_to(end_pos) <= 1.5:  # Allow for diagonal movement (sqrt(2) ≈ 1.414)
		# Check if end position is walkable
		var end_cell_type = grid_cells.get(str(end_pos), 0)
		if end_cell_type != 1:  # Not a barrier
			return [grid_to_world(end_pos)]

	# Check if we have a cached path
	var cache_key = str(start_pos) + "-" + str(end_pos)
	var current_time = Time.get_ticks_msec()
	
	# Check if cached path is too old (more than 5 seconds)
	if path_cache.has(cache_key) and path_cache_timestamps.has(cache_key):
		var cache_age = current_time - path_cache_timestamps[cache_key]
		if cache_age > 5000:  # 5 seconds in ms
			path_cache.erase(cache_key)  # Force recalculation
		elif not grid_changed:
			# Use cached path if it's not too old and grid hasn't changed
			return path_cache[cache_key]

	# Find new path using the A* algorithm from the old code
	var path = find_path(start_pos, end_pos)

	# Convert to world positions
	var world_path = []
	for pos in path:
		world_path.append(grid_to_world(pos))

	# Cache the path
	path_cache[cache_key] = world_path
	path_cache_timestamps[cache_key] = current_time

	# Reset grid changed flag
	grid_changed = false

	return world_path

# A* pathfinding implementation from the old code
func find_path(start_pos: Vector2, end_pos: Vector2) -> Array:
	print("Finding path from " + str(start_pos) + " to " + str(end_pos))

	# A* pathfinding implementation
	var open_set = []
	var closed_set = {}
	var came_from = {}

	var g_score = {}
	var f_score = {}

	# Initialize start node
	open_set.append(start_pos)
	g_score[str(start_pos)] = 0
	f_score[str(start_pos)] = heuristic(start_pos, end_pos)

	var max_iterations = 1000  # Prevent infinite loops
	var iterations = 0

	while open_set.size() > 0 and iterations < max_iterations:
		iterations += 1
		
		# Find node with lowest f_score
		var current_index = 0
		for i in range(1, open_set.size()):
			if f_score.get(str(open_set[i]), INF) < f_score.get(str(open_set[current_index]), INF):
				current_index = i
		
		var current = open_set[current_index]
		
		# If we reached the end
		if current.is_equal_approx(end_pos):
			var path = reconstruct_path(came_from, current)
			print("Path found with " + str(path.size()) + " steps")
			
			# Store the path for visualization but don't show it
			debug_path_to_draw = path.duplicate()
			if start_pos not in debug_path_to_draw:
				debug_path_to_draw.push_front(start_pos)
			show_debug_path = false  # Don't show the debug path
			queue_redraw()
			
			return path
		
		# Remove current from open set and add to closed set
		open_set.remove_at(current_index)
		closed_set[str(current)] = true
		
		# IMPORTANT: Only check 4 neighbors (no diagonals)
		var directions = [
			Vector2(1, 0),   # Right
			Vector2(-1, 0),  # Left
			Vector2(0, 1),   # Down
			Vector2(0, -1)   # Up
		]

		for direction in directions:
			var neighbor = Vector2(current.x + direction.x, current.y + direction.y)
			var neighbor_str = str(neighbor)
			
			# Skip if not within bounds
			if not is_within_bounds(neighbor):
				continue
			
			# Skip if in closed set
			if closed_set.get(neighbor_str, false):
				continue
			
			# Skip if neighbor is a barrier
			if grid_cells.get(neighbor_str, 0) == 1:
				continue
			
			# All moves cost the same in 4-directional movement
			var move_cost = 1.0
			
			# Calculate tentative g_score
			var tentative_g_score = g_score.get(str(current), INF) + move_cost
			
			# Skip if this path is worse
			if neighbor in open_set and tentative_g_score >= g_score.get(neighbor_str, INF):
				continue
			
			# This path is better, record it
			came_from[neighbor_str] = current
			g_score[neighbor_str] = tentative_g_score
			f_score[neighbor_str] = tentative_g_score + heuristic(neighbor, end_pos)
			
			if not neighbor in open_set:
				open_set.append(neighbor)

	print("No path found after " + str(iterations) + " iterations")

	# Clear the debug path if no path was found
	debug_path_to_draw.clear()
	show_debug_path = false
	queue_redraw()

	# If we get here, no path was found
	return []

# Helper function to convert string back to Vector2
func str_to_vector2(vec_str: String) -> Vector2:
	# Remove parentheses and split by comma
	vec_str = vec_str.replace("(", "").replace(")", "")
	var parts = vec_str.split(", ")
	if parts.size() == 2:
		return Vector2(float(parts[0]), float(parts[1]))
	return Vector2.ZERO

func reconstruct_path(came_from: Dictionary, current: Vector2) -> Array:
	var total_path = [current]
	var current_str = str(current)

	while came_from.has(current_str):
		current = came_from[current_str]
		current_str = str(current)
		total_path.push_front(current)

	# Remove the starting position
	if total_path.size() > 0:
		total_path.remove_at(0)

	return total_path

func heuristic(a: Vector2, b: Vector2) -> float:
	# Use Manhattan distance for 4-directional movement
	return abs(a.x - b.x) + abs(a.y - b.y)

# Find path specifically for heroes (respecting green zone)
func find_path_for_hero(start_pos: Vector2, end_pos: Vector2) -> Array:
	# Check if end position is in green zone
	if not is_in_green_zone(end_pos):
		return []

	# Check if start position is valid
	if not is_within_bounds(start_pos):
		return []

	# Check if we have a cached path
	var cache_key = "hero-" + str(start_pos) + "-" + str(end_pos)
	var current_time = Time.get_ticks_msec()
	
	# Check if cached path is too old (more than 5 seconds)
	if path_cache.has(cache_key) and path_cache_timestamps.has(cache_key):
		var cache_age = current_time - path_cache_timestamps[cache_key]
		if cache_age > 5000:  # 5 seconds in ms
			path_cache.erase(cache_key)  # Force recalculation
		elif not grid_changed:
			# Use cached path if it's not too old and grid hasn't changed
			return path_cache[cache_key]

	var path = find_path(start_pos, end_pos)

	# Cache the path
	path_cache[cache_key] = path
	path_cache_timestamps[cache_key] = current_time

	return path

func is_grid_changed() -> bool:
	return grid_changed

# Add this method to explicitly mark a cell as empty
func set_cell_empty(grid_pos: Vector2):
	if not is_within_bounds(grid_pos):
		return false
		
	var pos_key = str(grid_pos)

	# Check if the cell exists in the grid
	if grid_cells.has(pos_key):
		# Store the previous value for logging
		var previous_value = grid_cells[pos_key]
		
		# Set the cell to empty (0)
		grid_cells[pos_key] = 0
		
		# Mark grid as changed and clear path cache
		grid_changed = true
		path_cache.clear()
		path_cache_timestamps.clear()
		
		emit_signal("grid_updated")
		return true
	else:
		return false

# Set the debug path to visualize
func set_debug_path(path: Array):
	debug_path_to_draw = path
	show_debug_path = false  # Don't show the debug path
	queue_redraw()

# Clear the debug path
func clear_debug_path():
	debug_path_to_draw.clear()
	show_debug_path = false
	queue_redraw()

# Toggle debug path visualization
func toggle_debug_path(enable: bool):
	show_debug_path = false  # Always keep debug path hidden
	queue_redraw()
