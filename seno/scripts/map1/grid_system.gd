extends Node2D

# Grid properties
var cell_size = Vector2(64, 64)
var grid_size = Vector2i(20, 20)  # Default size, will be adjusted based on base position
var grid_offset = Vector2.ZERO

# Colors
var default_cell_color = Color(0.2, 0.8, 0.2, 0.3)  # Light green with transparency
var hover_cell_color = Color(0.3, 0.9, 0.3, 0.5)    # Darker green for hover
var invalid_cell_color = Color(0.8, 0.2, 0.2, 0.3)  # Red for invalid placement
var movement_cell_color = Color(0.2, 0.2, 0.8, 0.3) # Blue for movement range
var base_zone_color = Color(0.8, 0.8, 0.2, 0.2)     # Yellow for base zone

# State
var hover_cell = Vector2i(-1, -1)
var occupied_cells = {}  # Dictionary mapping Vector2i positions to occupying entities
var heroes = {}          # Dictionary mapping Vector2i positions to hero nodes
var barriers = {}        # Dictionary mapping Vector2i positions to barrier nodes
var showing_movement_grid = false
var movement_range_cells = []
var base_grid_pos = Vector2i(0, 0)
var base_zone_radius = 5  # Maximum distance from base in grid cells

func _ready():
	print("GridSystem ready with cell size: ", cell_size)

func _draw():
	# Draw the grid cells
	for x in range(-grid_size.x/2, grid_size.x/2):
		for y in range(-grid_size.y/2, grid_size.y/2):
			var cell_pos = Vector2i(x, y)
			var rect_pos = grid_to_world(cell_pos)
			
			# Determine cell color
			var cell_color = default_cell_color
			
			# Calculate distance to base
			var distance_to_base = cell_pos.distance_to(base_grid_pos)
			var in_base_zone = distance_to_base <= base_zone_radius
			
			# If we're showing movement grid, check if this cell is in movement range
			if showing_movement_grid and cell_pos in movement_range_cells:
				cell_color = movement_cell_color
			# Otherwise use normal coloring logic
			elif cell_pos == hover_cell:
				cell_color = hover_cell_color
			elif is_cell_occupied(cell_pos):
				cell_color = invalid_cell_color
			elif in_base_zone:
				cell_color = base_zone_color
			
			# Draw cell rectangle
			draw_rect(Rect2(rect_pos - cell_size/2, cell_size), cell_color, true)
			
			# Draw cell border
			draw_rect(Rect2(rect_pos - cell_size/2, cell_size), Color.BLACK, false)

func _process(_delta):
	# Update hover cell based on mouse position
	var mouse_pos = get_global_mouse_position()
	var new_hover_cell = world_to_grid(mouse_pos)
	
	if new_hover_cell != hover_cell:
		hover_cell = new_hover_cell
		queue_redraw()

func center_on_base(base_position):
	# Set the grid offset to center on the base
	grid_offset = base_position
	base_grid_pos = world_to_grid(base_position)
	print("Grid centered on base at position: ", base_position)
	print("Grid offset set to: ", grid_offset)
	print("Base grid position: ", base_grid_pos)
	queue_redraw()

func world_to_grid(world_pos):
	# Convert world position to grid position
	var relative_pos = world_pos - grid_offset
	var grid_pos = Vector2i(
		floor(relative_pos.x / cell_size.x),
		floor(relative_pos.y / cell_size.y)
	)
	return grid_pos

func grid_to_world(grid_pos):
	# Convert grid position to world position (center of cell)
	return Vector2(
		grid_pos.x * cell_size.x + cell_size.x/2,
		grid_pos.y * cell_size.y + cell_size.y/2
	) + grid_offset

func is_cell_occupied(grid_pos):
	# Check if a cell is occupied by any entity
	return occupied_cells.has(grid_pos)

func is_valid_placement_cell(grid_pos):
	# Check if a cell is valid for placement (within grid, not occupied, and in base zone)
	if abs(grid_pos.x) > grid_size.x/2 or abs(grid_pos.y) > grid_size.y/2:
		return false
	
	# Check if in base zone
	var distance_to_base = grid_pos.distance_to(base_grid_pos)
	if distance_to_base > base_zone_radius:
		return false
	
	return not is_cell_occupied(grid_pos)

func is_in_base_zone(grid_pos):
	# Check if a position is within the base zone
	var distance_to_base = grid_pos.distance_to(base_grid_pos)
	return distance_to_base <= base_zone_radius

func occupy_cell(grid_pos, entity):
	# Mark a cell as occupied by an entity
	occupied_cells[grid_pos] = entity
	print("Cell occupied at grid position: ", grid_pos)
	queue_redraw()
	return true

func is_valid_movement_cell(grid_pos):
	# Check if a cell is valid for movement (within grid, not occupied by barriers, and in movement range)
	if abs(grid_pos.x) > grid_size.x/2 or abs(grid_pos.y) > grid_size.y/2:
		return false
	
	if barriers.has(grid_pos):
		return false
	
	if showing_movement_grid:
		return grid_pos in movement_range_cells
	
	return true

func register_hero(hero, grid_pos):
	# Register a hero at a grid position
	heroes[grid_pos] = hero
	occupied_cells[grid_pos] = hero
	print("Hero registered at grid position: ", grid_pos)
	queue_redraw()

func update_hero_position(hero, new_grid_pos):
	# Update a hero's position in the grid
	var old_pos = null
	
	# Find the hero's old position
	for pos in heroes.keys():
		if heroes[pos] == hero:
			old_pos = pos
			break
	
	if old_pos:
		heroes.erase(old_pos)
		occupied_cells.erase(old_pos)
	
	# Register at new position
	heroes[new_grid_pos] = hero
	occupied_cells[new_grid_pos] = hero
	print("Hero moved from ", old_pos, " to ", new_grid_pos)
	queue_redraw()

func register_barrier(barrier, grid_pos):
	# Register a barrier at a grid position
	barriers[grid_pos] = barrier
	occupied_cells[grid_pos] = barrier
	print("Barrier registered at grid position: ", grid_pos)
	queue_redraw()

func remove_barrier(grid_pos):
	# Remove a barrier from a grid position
	if barriers.has(grid_pos):
		barriers.erase(grid_pos)
		occupied_cells.erase(grid_pos)
		print("Barrier removed from grid position: ", grid_pos)
		queue_redraw()
		return true
	return false

func show_movement_grid(center_pos, move_distance):
	# Show the movement grid for a hero
	showing_movement_grid = true
	movement_range_cells = calculate_movement_range(center_pos, move_distance)
	visible = true
	queue_redraw()
	print("Showing movement grid with ", movement_range_cells.size(), " cells")

func hide_movement_grid():
	# Hide the movement grid
	showing_movement_grid = false
	movement_range_cells = []
	queue_redraw()
	print("Movement grid hidden")

func calculate_movement_range(center_pos, move_distance):
	# Calculate cells within movement range using BFS
	var cells = []
	var queue = [center_pos]
	var visited = {center_pos: 0}  # Map position to distance
	
	while not queue.empty():
		var current = queue.pop_front()
		var current_distance = visited[current]
		
		# Add current cell to movement range
		cells.append(current)
		
		# If we've reached max distance, don't explore further
		if current_distance >= move_distance / cell_size.x:
			continue
		
		# Check neighbors
		var neighbors = [
			Vector2i(current.x + 1, current.y),
			Vector2i(current.x - 1, current.y),
			Vector2i(current.x, current.y + 1),
			Vector2i(current.x, current.y - 1)
		]
		
		for neighbor in neighbors:
			# Skip if outside grid
			if abs(neighbor.x) > grid_size.x/2 or abs(neighbor.y) > grid_size.y/2:
				continue
			
			# Skip if already visited
			if visited.has(neighbor):
				continue
			
			# Skip if occupied by barrier
			if barriers.has(neighbor):
				continue
			
			# Add to queue and mark as visited
			queue.append(neighbor)
			visited[neighbor] = current_distance + 1
	
	return cells

func find_path(start_pos, end_pos):
	# Find a path from start to end using A*
	var open_set = [start_pos]
	var came_from = {}
	
	var g_score = {start_pos: 0}  # Cost from start to current
	var f_score = {start_pos: heuristic(start_pos, end_pos)}  # Estimated total cost
	
	while not open_set.empty():
		# Find node with lowest f_score
		var current = open_set[0]
		var lowest_f = f_score[current]
		var current_index = 0
		
		for i in range(1, open_set.size()):
			var node = open_set[i]
			if f_score.has(node) and f_score[node] < lowest_f:
				lowest_f = f_score[node]
				current = node
				current_index = i
		
		# If we reached the end, reconstruct path
		if current == end_pos:
			return reconstruct_path(came_from, current)
		
		# Remove current from open set
		open_set.remove_at(current_index)
		
		# Check neighbors
		var neighbors = [
			Vector2i(current.x + 1, current.y),
			Vector2i(current.x - 1, current.y),
			Vector2i(current.x, current.y + 1),
			Vector2i(current.x, current.y - 1)
		]
		
		for neighbor in neighbors:
			# Skip if outside grid
			if abs(neighbor.x) > grid_size.x/2 or abs(neighbor.y) > grid_size.y/2:
				continue
			
			# Skip if occupied by barrier
			if barriers.has(neighbor):
				continue
			
			# Calculate tentative g_score
			var tentative_g = g_score[current] + 1
			
			# If this path is better than previous one
			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + heuristic(neighbor, end_pos)
				
				# Add to open set if not already there
				if not neighbor in open_set:
					open_set.append(neighbor)
	
	# No path found
	return []

func heuristic(a, b):
	# Manhattan distance
	return abs(a.x - b.x) + abs(a.y - b.y)

func reconstruct_path(came_from, current):
	# Reconstruct path from came_from map
	var path = [current]
	
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	
	return path
