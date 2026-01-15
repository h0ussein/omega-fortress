extends Node

signal wave_started(wave_number)
signal wave_completed(wave_number)
signal all_waves_completed
signal enemy_spawned(enemy)
signal countdown_tick(time_left)

# Wave configuration
@export var waves: Array[Dictionary] = []
@export var time_between_waves: float = 20.0
@export var first_wave_delay: float = 10.0
@export var spawn_distance_min: float = 500.0
@export var spawn_distance_max: float = 700.0

# Current state
var wave_number = 0
var current_wave: int = 0
var enemies_per_wave = 10
var enemies_to_spawn: Dictionary = {}
var active_enemies: int = 0
var wave_in_progress: bool = false
var countdown_active: bool = false
var time_to_next_wave: float = 0
var game_started: bool = false
var game_paused: bool = false
var enemy_spawn_interval = 1.0
var spawn_timer: Timer

# References
var enemy_scenes = {}
var spawn_points = []
var base_position: Vector2 = Vector2.ZERO
var grid_system = null

@onready var timer = Timer.new()

func _ready():
	# Add to wave_manager group for easier finding
	add_to_group("wave_manager")

	_load_enemy_scenes()
	
	# Find spawn points
	spawn_points = get_tree().get_nodes_in_group("enemy_spawn_point")
	
	# If no spawn points found, create dynamic spawn points
	if spawn_points.is_empty():
		print("WaveManager: No spawn points found, creating dynamic spawn points")
		_create_dynamic_spawn_points()
	
	print("WaveManager: Found " + str(spawn_points.size()) + " spawn points")
	
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)

	# Find the base position
	var bases = get_tree().get_nodes_in_group("base")
	print("WaveManager: Found ", bases.size(), " bases in group")

	if bases.size() > 0:
		base_position = bases[0].global_position
		print("WaveManager: Found base at position ", base_position)
	else:
		print("WaveManager: No base found! Using default position.")
		base_position = Vector2.ZERO

	# Find grid system
	grid_system = get_node_or_null("/root/Node2D_main/GridSystem")
	if grid_system:
		print("WaveManager: Found grid system")
	else:
		print("WaveManager: Grid system not found")

	# Create spawn timer
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	add_child(spawn_timer)
	print("WaveManager: Created spawn timer")

	# If no waves were configured, create some default waves
	if waves.is_empty():
		_create_default_waves()

	print("WaveManager: Ready with ", waves.size(), " waves")
	print("WaveManager: Signals available: wave_started=", has_signal("wave_started"), 
		  ", wave_completed=", has_signal("wave_completed"), 
		  ", countdown_tick=", has_signal("countdown_tick"))

# Create dynamic spawn points around the base
func _create_dynamic_spawn_points():
	# Create 8 spawn points in a circle around the base
	var num_points = 8
	for i in range(num_points):
		var angle = 2 * PI * i / num_points
		var distance = spawn_distance_min
		var pos = base_position + Vector2(cos(angle), sin(angle)) * distance
		
		# Create a spawn point node
		var spawn_point = Node2D.new()
		spawn_point.name = "DynamicSpawnPoint_" + str(i)
		spawn_point.global_position = pos
		spawn_point.add_to_group("enemy_spawn_point")
		
		# Add to the scene
		get_parent().add_child(spawn_point)
		
		# Add to our list
		spawn_points.append(spawn_point)
		
		print("WaveManager: Created dynamic spawn point at " + str(pos))

func _process(delta):
	if game_paused:
		return
		
	if countdown_active:
		time_to_next_wave -= delta
		emit_signal("countdown_tick", time_to_next_wave)
		
		if time_to_next_wave <= 0:
			countdown_active = false
			start_next_wave()

	if wave_in_progress and not spawn_timer.is_stopped() and spawn_timer.time_left <= 0:
		_process_spawning()

func start_wave():
	wave_number += 1
	print("Starting wave " + str(wave_number))
	timer.start(enemy_spawn_interval)

func _on_timer_timeout():
	# Modified to ensure we spawn all enemies for the wave
	spawn_enemy()
	
	# Check if we need to continue spawning
	if active_enemies < enemies_per_wave:
		# Restart the timer to spawn another enemy
		timer.start(enemy_spawn_interval)
	else:
		print("WaveManager: All " + str(enemies_per_wave) + " enemies spawned for wave")
		timer.stop()

func spawn_enemy():
	if enemy_scenes.has("skeleton"):
		if spawn_points.is_empty():
			print("WaveManager: ERROR - No spawn points available!")
			return
			
		var enemy = enemy_scenes["skeleton"].instantiate()
		var spawn_point = spawn_points[randi() % spawn_points.size()]
		
		# Verify the spawn point is valid
		if not is_instance_valid(spawn_point):
			print("WaveManager: ERROR - Invalid spawn point!")
			return
			
		enemy.global_position = spawn_point.global_position
		
		# Connect to enemy death signal
		if enemy.has_signal("died"):
			enemy.died.connect(_on_enemy_died)
			
		get_tree().root.add_child(enemy)
		active_enemies += 1
		print("WaveManager: Spawned enemy " + str(active_enemies) + " of " + str(enemies_per_wave) + " at " + str(enemy.global_position))
	else:
		print("WaveManager: ERROR - No skeleton scene loaded!")

func _load_enemy_scenes():
	# Use the correct path for your enemy scene
	var skeleton_scene_path = "res://scenes/enemies/enemy_1.tscn"  # Updated to the path that worked in the log
	if ResourceLoader.exists(skeleton_scene_path):
		enemy_scenes["skeleton"] = load(skeleton_scene_path)
		print("WaveManager: Loaded skeleton enemy scene from " + skeleton_scene_path)
	else:
		print("WaveManager: Failed to load skeleton enemy scene from " + skeleton_scene_path)
		
		# Try alternative paths if the first one fails
		var alt_paths = [
			"res://enemy_1.tscn",
			"res://scenes/enemy_1.tscn",
			"res://scripts/enemy_1.tscn"
		]
		
		for alt_path in alt_paths:
			if ResourceLoader.exists(alt_path):
				enemy_scenes["skeleton"] = load(alt_path)
				print("WaveManager: Loaded skeleton enemy scene from alternative path: " + alt_path)
				break

func _create_default_waves():
	# Create some default waves with increasing difficulty
	waves = [
		{
			"enemies": {"skeleton": 10},
			"spawn_interval": 1.0
		},
		{
			"enemies": {"skeleton": 15},
			"spawn_interval": 0.8
		},
		{
			"enemies": {"skeleton": 20},
			"spawn_interval": 0.6
		},
		{
			"enemies": {"skeleton": 25},
			"spawn_interval": 0.5
		},
		{
			"enemies": {"skeleton": 30},
			"spawn_interval": 0.4
		}
	]
	print("WaveManager: Created " + str(waves.size()) + " default waves")

func start_game():
	print("WaveManager: start_game() called")

	if game_started:
		print("WaveManager: Game already started, ignoring")
		return
		
	game_started = true
	current_wave = 0
	active_enemies = 0  # Reset active enemies count

	# Start countdown to first wave
	time_to_next_wave = first_wave_delay
	countdown_active = true

	print("WaveManager: Game started, first wave in ", first_wave_delay, " seconds")

func start_next_wave():
	if current_wave >= waves.size():
		print("WaveManager: All waves completed!")
		emit_signal("all_waves_completed")
		return

	wave_in_progress = true
	var wave_data = waves[current_wave]
	active_enemies = 0  # Reset active enemies count

	# Set up enemies to spawn
	enemies_to_spawn = wave_data.enemies.duplicate()
	
	# Calculate total enemies for this wave
	var total_enemies = 0
	for enemy_type in enemies_to_spawn:
		total_enemies += enemies_to_spawn[enemy_type]
	
	# Update enemies_per_wave for this wave
	enemies_per_wave = total_enemies

	print("WaveManager: Starting wave " + str(current_wave + 1) + " with " + str(enemies_per_wave) + " enemies")
	emit_signal("wave_started", current_wave + 1)

	# Start spawning enemies using the timer-based approach
	timer.wait_time = wave_data.get("spawn_interval", 1.0)
	timer.start()
	print("WaveManager: Started enemy spawning timer with interval " + str(timer.wait_time))

func skip_countdown():
	if countdown_active:
		countdown_active = false
		start_next_wave()
		print("WaveManager: Countdown skipped, starting wave immediately")

func _process_spawning():
	# This function is now only used for the dictionary-based spawning approach
	# We're using the timer-based approach instead
	pass

func _spawn_enemy(enemy_type: String):
	if not enemy_scenes.has(enemy_type):
		print("WaveManager: Enemy type not found: " + enemy_type)
		return

	# Generate a random position around the base
	var spawn_position = _get_random_spawn_position()

	# Instantiate the enemy
	var enemy_scene = enemy_scenes[enemy_type]
	var enemy = enemy_scene.instantiate()

	# Position at spawn position
	enemy.global_position = spawn_position

	# Connect to enemy death signal
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)

	# Add to the scene
	get_parent().add_child(enemy)

	print("WaveManager: Spawned " + enemy_type + " at " + str(spawn_position))
	emit_signal("enemy_spawned", enemy)

func _get_random_spawn_position() -> Vector2:
	# Generate a random angle
	var angle = randf() * 2.0 * PI

	# Generate a random distance between min and max
	var distance = randf_range(spawn_distance_min, spawn_distance_max)

	# Calculate position
	var offset = Vector2(cos(angle), sin(angle)) * distance
	var spawn_pos = base_position + offset

	# If we have a grid system, make sure the position is valid
	if grid_system and grid_system.has_method("is_within_bounds"):
		var grid_pos = grid_system.world_to_grid(spawn_pos)
		
		# Make sure the position is within bounds
		if not grid_system.is_within_bounds(grid_pos):
			# Try again with a different angle
			return _get_random_spawn_position()
		
		# Make sure the position is not on a barrier
		if grid_system.grid_cells.get(str(grid_pos), 0) == 1:  # 1 = barrier
			# Try again with a different angle
			return _get_random_spawn_position()

	return spawn_pos

func _on_enemy_died(enemy):
	active_enemies -= 1
	print("WaveManager: Enemy died, " + str(active_enemies) + " enemies remaining")

	# Check if wave is complete
	if active_enemies <= 0 and timer.is_stopped():
		_complete_wave()

func _complete_wave():
	wave_in_progress = false
	current_wave += 1

	print("WaveManager: Wave " + str(current_wave) + " completed")
	emit_signal("wave_completed", current_wave)

	# Check if all waves are completed
	if current_wave >= waves.size():
		print("WaveManager: All waves completed!")
		emit_signal("all_waves_completed")
		return

	# Start countdown to next wave
	time_to_next_wave = time_between_waves
	countdown_active = true

	print("WaveManager: Next wave in " + str(time_between_waves) + " seconds")

func set_paused(paused: bool):
	game_paused = paused

	# Pause/unpause the spawn timer
	if spawn_timer:
		spawn_timer.paused = paused
	
	# Pause/unpause the main timer
	if timer:
		timer.paused = paused

# Get current wave number (1-based for display)
func get_current_wave() -> int:
	return current_wave + 1

# Get total number of waves
func get_total_waves() -> int:
	return waves.size()

# Get time remaining until next wave
func get_time_to_next_wave() -> float:
	return time_to_next_wave

# Check if a wave is in progress
func is_wave_in_progress() -> bool:
	return wave_in_progress

# Check if countdown to next wave is active
func is_countdown_active() -> bool:
	return countdown_active
