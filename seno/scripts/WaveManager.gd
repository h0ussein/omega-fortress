extends Node

signal wave_started(wave_number)
signal wave_completed(wave_number)
signal all_waves_completed
signal enemy_spawned(enemy)
signal enemy_killed(enemy)  # Added for WaveDisplayManager
signal countdown_tick(time_left)
signal boss_wave_started(wave_number)  # New signal for boss waves

# Wave configuration
@export var waves: Array[Dictionary] = []
@export var time_between_waves: float = 20.0
@export var first_wave_delay: float = 5.0
@export var spawn_distance_min: float = 500.0
@export var spawn_distance_max: float = 700.0
@export var wave_duration: float = 60.0  # 1 minute wave duration
@export var auto_start_next_wave: bool = true  # Add this to control auto-start behavior
@export var boss_wave_delay: float = 10.0  # Extra delay before boss waves
@export var min_spawn_interval: float = 0.5  # Minimum time between enemy spawns (500ms)

# Current state
var wave_number = 0
var current_wave: int = 0
var enemies_per_wave = 10
var enemies_to_spawn: Dictionary = {}
var active_enemies: int = 0
var enemies_spawned: int = 0  # Track how many enemies we've spawned
var enemies_killed: int = 0   # Track how many enemies have been killed
var wave_in_progress: bool = false
var countdown_active: bool = false
var time_to_next_wave: float = 0
var game_started: bool = false
var game_paused: bool = false
var total_enemies_in_wave: int = 0  # Total enemies in current wave
var current_boss_enemy = null  # Reference to current boss enemy if any
var wave_start_time: float = 0.0  # Track when the wave started
var wave_elapsed_time: float = 0.0  # Track elapsed time in the wave
var spawn_times: Array = []  # Array to store scheduled spawn times

# References
var enemy_scenes = {}
var spawn_points = []
var base_position: Vector2 = Vector2.ZERO
var grid_system = null
var wave_display_manager = null  # Reference to WaveDisplayManager

# Timers
@onready var countdown_timer = Timer.new()
@onready var wave_timer = Timer.new()
@onready var spawn_timer = Timer.new()

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

	# Find WaveDisplayManager
	wave_display_manager = get_node_or_null("/root/Node_main/WaveDisplayManager")
	if not wave_display_manager:
		# Try to find it in the scene
		var potential_displays = get_tree().get_nodes_in_group("wave_display_manager")
		if potential_displays.size() > 0:
			wave_display_manager = potential_displays[0]
			print("WaveManager: Found WaveDisplayManager in group")
		else:
			print("WaveManager: WaveDisplayManager not found")
	else:
		print("WaveManager: Found WaveDisplayManager at path")

	# Set up timers
	_setup_timers()

	# If no waves were configured, create some default waves
	if waves.is_empty():
		_create_default_waves()
	else:
		# If waves were already configured, adjust their spawn intervals
		adjust_wave_spawn_intervals()

	print("WaveManager: Ready with ", waves.size(), " waves")
	print("WaveManager: Signals available: wave_started=", has_signal("wave_started"), 
		  ", wave_completed=", has_signal("wave_completed"), 
		  ", countdown_tick=", has_signal("countdown_tick"),
		  ", enemy_killed=", has_signal("enemy_killed"),
		  ", boss_wave_started=", has_signal("boss_wave_started"))

func _setup_timers():
	# Countdown timer (for between waves)
	add_child(countdown_timer)
	countdown_timer.one_shot = true
	countdown_timer.timeout.connect(_on_countdown_timer_timeout)
	
	# Wave timer (for tracking wave duration)
	add_child(wave_timer)
	wave_timer.one_shot = true
	wave_timer.timeout.connect(_on_wave_timer_timeout)
	
	# Spawn timer (for spawning enemies)
	add_child(spawn_timer)
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	print("WaveManager: Timers set up")

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
		
	# Handle countdown between waves
	if countdown_active and not countdown_timer.is_stopped():
		time_to_next_wave = countdown_timer.time_left
		emit_signal("countdown_tick", time_to_next_wave)

	# Handle wave in progress
	if wave_in_progress:
		# Update wave elapsed time
		wave_elapsed_time = wave_duration - wave_timer.time_left
		
		# Force wave completion if it's taking too long (more than wave_duration + 10 seconds)
		if wave_elapsed_time > wave_duration + 10.0 and not is_boss_wave():
			print("WaveManager: Wave taking too long (", wave_elapsed_time, " seconds), forcing completion")
			_complete_wave()

func _on_countdown_timer_timeout():
	countdown_active = false
	print("WaveManager: Countdown finished, starting next wave")
	start_next_wave()

func _on_wave_timer_timeout():
	print("WaveManager: Wave timer expired, checking if wave should complete")
	
	# For boss waves, check if the boss is still alive
	if is_boss_wave() and current_boss_enemy != null and is_instance_valid(current_boss_enemy):
		print("WaveManager: Boss wave time expired but boss still alive. Waiting for boss defeat.")
		# Start a safety timer to force completion if it takes too long
		var safety_timer = Timer.new()
		safety_timer.one_shot = true
		safety_timer.wait_time = 30.0  # 30 second grace period
		add_child(safety_timer)
		safety_timer.timeout.connect(func():
			print("WaveManager: Boss wave safety timeout - forcing completion")
			_complete_wave()
			safety_timer.queue_free()
		)
		safety_timer.start()
	else:
		print("WaveManager: Wave duration reached, forcing completion")
		_complete_wave()

func _on_spawn_timer_timeout():
	# Check if we have any enemies left to spawn
	if spawn_times.is_empty():
		print("WaveManager: No more scheduled spawns")
		return
	
	# Get the next spawn time
	var next_spawn = spawn_times.pop_front()
	
	# Spawn the enemy
	spawn_enemy()
	
	# If we have more enemies to spawn, schedule the next one
	if not spawn_times.is_empty():
		var time_to_next = spawn_times[0] - next_spawn
		spawn_timer.start(time_to_next)
		print("WaveManager: Next enemy spawn in ", time_to_next, " seconds")

func spawn_enemy():
	print("WaveManager: Attempting to spawn enemy")
	
	# CRITICAL: Check if we're still in the scene tree
	if not is_inside_tree():
		print("WaveManager: ERROR - Cannot spawn enemy, no longer in scene tree")
		return false
	
	# Get a list of enemy types that still have enemies to spawn
	var available_enemy_types = []
	for enemy_type in enemies_to_spawn:
		if enemies_to_spawn[enemy_type] > 0:
			available_enemy_types.append(enemy_type)
	
	if available_enemy_types.is_empty():
		print("WaveManager: No more enemies to spawn in this wave")
		return false
	
	# Randomly select an enemy type from the available types
	var enemy_type_to_spawn = available_enemy_types[randi() % available_enemy_types.size()]
	print("WaveManager: Selected enemy type: " + enemy_type_to_spawn)
	
	if not enemy_scenes.has(enemy_type_to_spawn):
		print("WaveManager: Enemy type not found in enemy_scenes dictionary: " + enemy_type_to_spawn)
		return false
	
	if enemy_scenes[enemy_type_to_spawn] == null:
		print("WaveManager: Enemy scene is null for type: " + enemy_type_to_spawn)
		return false
		
	if spawn_points.is_empty():
		print("WaveManager: ERROR - No spawn points available!")
		return false
	
	# Find a valid spawn point
	var spawn_point = null
	var valid_spawn_points = []
	
	for point in spawn_points:
		if is_instance_valid(point):
			valid_spawn_points.append(point)
	
	if valid_spawn_points.is_empty():
		print("WaveManager: ERROR - No valid spawn points!")
		return false
	
	spawn_point = valid_spawn_points[randi() % valid_spawn_points.size()]
	print("WaveManager: Selected spawn point at " + str(spawn_point.global_position))
	
	# CRITICAL: Check if we can get the scene tree
	var tree = get_tree()
	if tree == null:
		print("WaveManager: ERROR - Cannot get scene tree!")
		return false
	
	# CRITICAL: Check if we can get the root
	var root = tree.get_root()
	if root == null:
		print("WaveManager: ERROR - Cannot get scene root!")
		return false
	
	# Try to instantiate the enemy
	var enemy = null
	
	# Use a try-catch block to handle any instantiation errors
	print("WaveManager: Attempting to instantiate enemy of type: " + enemy_type_to_spawn)
	
	# Create a direct reference to the scene to avoid any potential issues
	var enemy_scene = enemy_scenes[enemy_type_to_spawn]
	
	# Try to instantiate the enemy
	enemy = enemy_scene.instantiate()
	if enemy == null:
		print("WaveManager: ERROR - Failed to instantiate enemy!")
		return false
	
	print("WaveManager: Enemy instantiated successfully")
	
	# Set the enemy position
	enemy.global_position = spawn_point.global_position
	print("WaveManager: Set enemy position to " + str(enemy.global_position))

	# Check if this is a boss enemy
	var is_boss = false
	if is_boss_wave() and (enemy_type_to_spawn == "boss1" or enemy_type_to_spawn == "boss2" or enemy_type_to_spawn == "boss3"):
		is_boss = true
		print("WaveManager: This is a boss enemy of type: " + enemy_type_to_spawn)
		
		# Make boss enemy special
		if enemy.has_method("set_as_boss"):
			print("WaveManager: Calling set_as_boss on boss enemy")
			enemy.set_as_boss()
		else:
			print("WaveManager: Boss doesn't have set_as_boss method, manually enhancing")
			# Manually enhance the boss if no set_as_boss method
			if "max_health" in enemy:
				enemy.max_health *= 3.0
				enemy.health = enemy.max_health
			if "scale" in enemy:
				enemy.scale *= 1.5
			if "modulate" in enemy:
				enemy.modulate = Color(1.0, 0.5, 0.5)  # Reddish tint
		
		print("WaveManager: Spawned BOSS enemy!")
		current_boss_enemy = enemy

	# Connect to enemy death signal
	if enemy.has_signal("died"):
		print("WaveManager: Connected to enemy died signal")
		enemy.died.connect(_on_enemy_died)
	else:
		print("WaveManager: WARNING - Enemy doesn't have died signal!")
	
	# Add the enemy to the scene
	print("WaveManager: Adding enemy to scene")
	
	# CRITICAL: Use add_child instead of directly adding to root
	# This ensures the enemy is added as a child of the wave manager
	add_child(enemy)
	
	print("WaveManager: Enemy added to scene successfully")
	
	active_enemies += 1
	enemies_spawned += 1
	enemies_to_spawn[enemy_type_to_spawn] -= 1

	print("WaveManager: Spawned " + enemy_type_to_spawn + " " + str(enemies_spawned) + " of " + str(enemies_per_wave) + " at " + str(enemy.global_position))
	emit_signal("enemy_spawned", enemy)

	# If this is a boss, emit a special signal
	if is_boss:
		print("WaveManager: Emitting boss_wave_started signal")
		emit_signal("boss_wave_started", current_wave + 1)

	return true

func _load_enemy_scenes():
	# Load boss scenes first to ensure they're available for wave 5
	print("WaveManager: Loading boss scenes first")
	
	# Load boss 1
	var boss1_scene_path = "res://scenes/enemies/boss_1.tscn"
	if ResourceLoader.exists(boss1_scene_path):
		enemy_scenes["boss1"] = load(boss1_scene_path)
		print("WaveManager: Loaded boss1 scene from " + boss1_scene_path)
	else:
		print("WaveManager: Failed to load boss1 scene from " + boss1_scene_path)
		
		# Try alternative paths
		var alt_paths = [
			"res://boss_1.tscn",
			"res://scripts/enemies/boss_1.tscn"
		]
		
		for alt_path in alt_paths:
			if ResourceLoader.exists(alt_path):
				enemy_scenes["boss1"] = load(alt_path)
				print("WaveManager: Loaded boss1 scene from alternative path: " + alt_path)
				break
		
		# If still not found, try to create a scene from the script
		if not enemy_scenes.has("boss1") or enemy_scenes["boss1"] == null:
			print("WaveManager: Attempting to create boss1 scene from script")
			var script_path = "res://scripts/enemies/boss_1.gd"
			if ResourceLoader.exists(script_path):
				var script = load(script_path)
				var scene = PackedScene.new()
				var node = CharacterBody2D.new()
				node.set_script(script)
				node.name = "Boss1"
				
				var err = scene.pack(node)
				if err == OK:
					enemy_scenes["boss1"] = scene
					print("WaveManager: Created boss1 scene from script")
				else:
					print("WaveManager: Failed to create boss1 scene from script")
			else:
				print("WaveManager: Boss1 script not found at " + script_path)
	
	# Load boss 2
	var boss2_scene_path = "res://scenes/enemies/enemy_7.tscn"
	if ResourceLoader.exists(boss2_scene_path):
		enemy_scenes["boss2"] = load(boss2_scene_path)
		print("WaveManager: Loaded boss2 scene from " + boss2_scene_path)
	else:
		print("WaveManager: Failed to load boss2 scene from " + boss2_scene_path)
		
		# Try alternative paths
		var alt_paths = [
			"res://boss_2.tscn",
			"res://scripts/enemies/boss_2.tscn"
		]
		
		for alt_path in alt_paths:
			if ResourceLoader.exists(alt_path):
				enemy_scenes["boss2"] = load(alt_path)
				print("WaveManager: Loaded boss2 scene from alternative path: " + alt_path)
				break
		
		# If still not found, try to create a scene from the script
		if not enemy_scenes.has("boss2") or enemy_scenes["boss2"] == null:
			print("WaveManager: Attempting to create boss2 scene from script")
			var script_path = "res://scripts/enemies/boss_2.gd"
			if ResourceLoader.exists(script_path):
				var script = load(script_path)
				var scene = PackedScene.new()
				var node = CharacterBody2D.new()
				node.set_script(script)
				node.name = "Boss2"
				
				var err = scene.pack(node)
				if err == OK:
					enemy_scenes["boss2"] = scene
					print("WaveManager: Created boss2 scene from script")
				else:
					print("WaveManager: Failed to create boss2 scene from script")
			else:
				print("WaveManager: Boss2 script not found at " + script_path)
	
	# Load boss 3
	var boss3_scene_path = "res://scenes/enemies/boss_2.tscn"
	if ResourceLoader.exists(boss3_scene_path):
		enemy_scenes["boss3"] = load(boss3_scene_path)
		print("WaveManager: Loaded boss3 scene from " + boss3_scene_path)
	else:
		print("WaveManager: Failed to load boss3 scene from " + boss3_scene_path)
		
		# Try alternative paths
		var alt_paths = [
			"res://boss_3.tscn",
			"res://scripts/enemies/boss_3.tscn"
		]
		
		for alt_path in alt_paths:
			if ResourceLoader.exists(alt_path):
				enemy_scenes["boss3"] = load(alt_path)
				print("WaveManager: Loaded boss3 scene from alternative path: " + alt_path)
				break
		
		# If still not found, try to create a scene from the script
		if not enemy_scenes.has("boss3") or enemy_scenes["boss3"] == null:
			print("WaveManager: Attempting to create boss3 scene from script")
			var script_path = "res://scripts/enemies/boss_3.gd"
			if ResourceLoader.exists(script_path):
				var script = load(script_path)
				var scene = PackedScene.new()
				var node = CharacterBody2D.new()
				node.set_script(script)
				node.name = "Boss3"
				
				var err = scene.pack(node)
				if err == OK:
					enemy_scenes["boss3"] = scene
					print("WaveManager: Created boss3 scene from script")
				else:
					print("WaveManager: Failed to create boss3 scene from script")
			else:
				print("WaveManager: Boss3 script not found at " + script_path)
	
	# Now load regular enemies
	print("WaveManager: Loading regular enemy scenes")
	
	# Load enemy 1
	var enemy1_scene_path = "res://scenes/enemies/enemy_1.tscn"
	if ResourceLoader.exists(enemy1_scene_path):
		enemy_scenes["enemy1"] = load(enemy1_scene_path)
		print("WaveManager: Loaded enemy1 scene from " + enemy1_scene_path)
	else:
		print("WaveManager: Failed to load enemy1 scene from " + enemy1_scene_path)
		
		# Try alternative paths if the first one fails
		var alt_paths = [
			"res://enemy_1.tscn",
			"res://scenes/enemy_1.tscn",
			"res://scripts/enemy_1.tscn"
		]
		
		for alt_path in alt_paths:
			if ResourceLoader.exists(alt_path):
				enemy_scenes["enemy1"] = load(alt_path)
				print("WaveManager: Loaded enemy1 scene from alternative path: " + alt_path)
				break

	# Load enemy 2
	var enemy2_scene_path = "res://scenes/enemies/enemy_2.tscn"
	if ResourceLoader.exists(enemy2_scene_path):
		enemy_scenes["enemy2"] = load(enemy2_scene_path)
		print("WaveManager: Loaded enemy2 scene from " + enemy2_scene_path)
	else:
		print("WaveManager: Failed to load enemy2 scene from " + enemy2_scene_path)
		
		# Try alternative paths if the first one fails
		var alt_paths = [
			"res://enemy_2.tscn",
			"res://scenes/enemy_2.tscn",
			"res://scripts/enemy_2.tscn"
		]
		
		for alt_path in alt_paths:
			if ResourceLoader.exists(alt_path):
				enemy_scenes["enemy2"] = load(alt_path)
				print("WaveManager: Loaded enemy2 scene from alternative path: " + alt_path)
				break

	# Load enemy 3
	var enemy3_scene_path = "res://scenes/enemies/enemy_3.tscn"
	if ResourceLoader.exists(enemy3_scene_path):
		enemy_scenes["enemy3"] = load(enemy3_scene_path)
		print("WaveManager: Loaded enemy3 scene from " + enemy3_scene_path)
	else:
		print("WaveManager: Failed to load enemy3 scene from " + enemy3_scene_path)
		
		# Try alternative paths if the first one fails
		var alt_paths = [
			"res://enemy_3.tscn",
			"res://scenes/enemy_3.tscn",
			"res://scripts/enemies/enemy_3.gd"
		]
		
		for alt_path in alt_paths:
			if ResourceLoader.exists(alt_path):
				enemy_scenes["enemy3"] = load(alt_path)
				print("WaveManager: Loaded enemy3 scene from alternative path: " + alt_path)
				break

	# Load enemy 4
	var enemy4_scene_path = "res://scenes/enemies/enemy_4.tscn"
	if ResourceLoader.exists(enemy4_scene_path):
		enemy_scenes["enemy4"] = load(enemy4_scene_path)
		print("WaveManager: Loaded enemy4 scene from " + enemy4_scene_path)
	else:
		print("WaveManager: Failed to load enemy4 scene from " + enemy4_scene_path)
		
		# Try alternative paths if the first one fails
		var alt_paths = [
			"res://enemy_4.tscn",
			"res://scenes/enemy_4.tscn",
			"res://scripts/enemies/enemy_4.gd"
		]
		
		for alt_path in alt_paths:
			if ResourceLoader.exists(alt_path):
				enemy_scenes["enemy4"] = load(alt_path)
				print("WaveManager: Loaded enemy4 scene from alternative path: " + alt_path)
				break

	# Load enemy 5
	var enemy5_scene_path = "res://scenes/enemies/enemy_5.tscn"
	if ResourceLoader.exists(enemy5_scene_path):
		enemy_scenes["enemy5"] = load(enemy5_scene_path)
		print("WaveManager: Loaded enemy5 scene from " + enemy5_scene_path)
	else:
		print("WaveManager: Failed to load enemy5 scene from " + enemy5_scene_path)
		
		# Try alternative paths if the first one fails
		var alt_paths = [
			"res://enemy_5.tscn",
			"res://scenes/enemy_5.tscn",
			"res://scripts/enemies/enemy_5.gd"
		]
		
		for alt_path in alt_paths:
			if ResourceLoader.exists(alt_path):
				enemy_scenes["enemy5"] = load(alt_path)
				print("WaveManager: Loaded enemy5 scene from alternative path: " + alt_path)
				break

	# Load enemy 6
	var enemy6_scene_path = "res://scenes/enemies/enemy_6.tscn"
	if ResourceLoader.exists(enemy6_scene_path):
		enemy_scenes["enemy6"] = load(enemy6_scene_path)
		print("WaveManager: Loaded enemy6 scene from " + enemy6_scene_path)
	else:
		print("WaveManager: Failed to load enemy6 scene from " + enemy6_scene_path)
		
		# Try alternative paths if the first one fails
		var alt_paths = [
			"res://enemy_6.tscn",
			"res://scenes/enemy_6.tscn",
			"res://scripts/enemies/enemy_6.gd"
		]
		
		for alt_path in alt_paths:
			if ResourceLoader.exists(alt_path):
				enemy_scenes["enemy6"] = load(alt_path)
				print("WaveManager: Loaded enemy6 scene from alternative path: " + alt_path)
				break
	
	# Load enemy 8 (barrier destroyer)
	var enemy8_scene_path = "res://scenes/enemies/enemy_8.tscn"
	if ResourceLoader.exists(enemy8_scene_path):
		enemy_scenes["enemy8"] = load(enemy8_scene_path)
		print("WaveManager: Loaded enemy8 scene from " + enemy8_scene_path)
	else:
		print("WaveManager: Failed to load enemy8 scene from " + enemy8_scene_path)
		
		# Try alternative paths if the first one fails
		var alt_paths = [
			"res://enemy_8.tscn",
			"res://scenes/enemy_8.tscn",
			"res://scripts/enemies/enemy_8.gd"
		]
		
		for alt_path in alt_paths:
			if ResourceLoader.exists(alt_path):
				enemy_scenes["enemy8"] = load(alt_path)
				print("WaveManager: Loaded enemy8 scene from alternative path: " + alt_path)
				break
	
	# Print summary of loaded scenes
	print("WaveManager: Enemy scenes loaded:")
	for enemy_type in enemy_scenes:
		if enemy_scenes[enemy_type] != null:
			print("  - " + enemy_type + ": OK")
		else:
			print("  - " + enemy_type + ": MISSING")

func _create_default_waves():
	# Modified to create exactly 10 waves with bosses at waves 3, 7, and 10
	waves = [
		# Wave 1
		{
			"enemies": {"enemy1": 8, "enemy2": 4, "enemy3": 0, "enemy4": 0, "enemy5": 0, "enemy6": 0, "enemy8": 0},
			"is_boss_wave": false
		},
		# Wave 2
		{
			"enemies": {"enemy1": 12, "enemy2": 8, "enemy3": 4, "enemy4": 0, "enemy5": 0, "enemy6": 0, "enemy8": 5},
			"is_boss_wave": false
		},
		# Wave 3 - BOSS WAVE (boss1)
		{
			"enemies": {"enemy1": 0, "enemy2": 0, "enemy3": 0, "enemy4": 0, "enemy5": 0, "enemy6": 0, "enemy8": 0, "boss1": 1},
			"is_boss_wave": true
		},
		# Wave 4
		{
			"enemies": {"enemy1": 20, "enemy2": 15, "enemy3": 12, "enemy4": 8, "enemy5": 4, "enemy6": 0, "enemy8": 10},
			"is_boss_wave": false
		},
		# Wave 5
		{
			"enemies": {"enemy1": 25, "enemy2": 20, "enemy3": 15, "enemy4": 12, "enemy5": 8, "enemy6": 4, "enemy8": 12},
			"is_boss_wave": false
		},
		# Wave 6
		{
			"enemies": {"enemy1": 30, "enemy2": 25, "enemy3": 20, "enemy4": 15, "enemy5": 12, "enemy6": 8, "enemy8": 15},
			"is_boss_wave": false
		},
		# Wave 7 - BOSS WAVE (boss2)
		{
			"enemies": {"enemy1": 0, "enemy2": 0, "enemy3": 0, "enemy4": 0, "enemy5": 0, "enemy6": 0, "enemy8": 0, "boss2": 1},
			"is_boss_wave": true
		},
		# Wave 8
		{
			"enemies": {"enemy1": 40, "enemy2": 35, "enemy3": 30, "enemy4": 25, "enemy5": 20, "enemy6": 15, "enemy8": 20},
			"is_boss_wave": false
		},
		# Wave 9
		{
			"enemies": {"enemy1": 50, "enemy2": 45, "enemy3": 40, "enemy4": 35, "enemy5": 30, "enemy6": 25, "enemy8": 25},
			"is_boss_wave": false
		},
		# Wave 10 - BOSS WAVE (boss3 - final boss)
		{
			"enemies": {"enemy1": 0, "enemy2": 0, "enemy3": 0, "enemy4": 0, "enemy5": 0, "enemy6": 0, "enemy8": 0, "boss3": 1},
			"is_boss_wave": true
		}
	]
	print("WaveManager: Created " + str(waves.size()) + " custom waves with bosses at waves 3, 7, and 10")

func adjust_wave_spawn_intervals():
	print("WaveManager: Adjusting all wave spawn intervals for 1-minute duration")
	
	for i in range(waves.size()):
		var wave_data = waves[i]
		var total_enemies = 0
		
		# Calculate total enemies in this wave
		for enemy_type in wave_data.enemies:
			total_enemies += wave_data.enemies[enemy_type]
		
		print("WaveManager: Wave " + str(i+1) + " - " + str(total_enemies) + " enemies")
	
	print("WaveManager: All wave spawn intervals adjusted")

func start_game():
	print("WaveManager: start_game() called")

	if game_started:
		print("WaveManager: Game already started, ignoring")
		return
		
	game_started = true
	current_wave = 0
	active_enemies = 0  # Reset active enemies count
	enemies_killed = 0  # Reset killed enemies count

	# Start countdown to first wave
	time_to_next_wave = first_wave_delay
	countdown_active = true
	countdown_timer.start(first_wave_delay)

	print("WaveManager: Game started, first wave in ", first_wave_delay, " seconds")

func start_next_wave():
	print("WaveManager: STARTING WAVE " + str(current_wave + 1))
	
	# Safety check - make sure we're not in a wave already
	if wave_in_progress:
		print("WaveManager: WARNING - Trying to start a wave while one is in progress. Forcing completion.")
		_complete_wave()
	if current_wave >= waves.size():
		print("WaveManager: All waves completed!")
		emit_signal("all_waves_completed")
		return

	wave_in_progress = true
	var wave_data = waves[current_wave]
	active_enemies = 0  # Reset active enemies count
	enemies_spawned = 0  # Reset spawned counter
	enemies_killed = 0   # Reset killed counter
	
	# Record wave start time
	wave_start_time = Time.get_ticks_msec() / 1000.0
	wave_elapsed_time = 0.0

	# Set up enemies to spawn
	enemies_to_spawn = wave_data.enemies.duplicate()
	
	# Calculate total enemies for this wave
	var total_enemies = 0
	for enemy_type in enemies_to_spawn:
		total_enemies += enemies_to_spawn[enemy_type]
	
	# Update enemies_per_wave for this wave
	enemies_per_wave = total_enemies
	total_enemies_in_wave = total_enemies

	print("WaveManager: Starting wave " + str(current_wave + 1) + " with " + str(enemies_per_wave) + " enemies")
	emit_signal("wave_started", current_wave + 1)

	# Check if this is a boss wave and announce it
	if is_boss_wave():
		print("WaveManager: THIS IS A BOSS WAVE!")
		_announce_boss_wave()
		
		# For boss waves, spawn immediately
		_schedule_enemy_spawns(0.5)  # Spawn boss after 0.5 seconds
	else:
		# For regular waves, distribute spawns over the wave duration
		_schedule_enemy_spawns(wave_duration)
	
	# Start the wave timer
	wave_timer.start(wave_duration)
	print("WaveManager: Wave timer started for ", wave_duration, " seconds")

func _schedule_enemy_spawns(duration: float):
	# Clear any existing spawn times
	spawn_times.clear()
	
	# For boss waves, just spawn immediately
	if is_boss_wave():
		spawn_times.append(0.5)  # Spawn boss after 0.5 seconds
		spawn_timer.start(0.5)
		print("WaveManager: Boss will spawn in 0.5 seconds")
		return
	
	# Calculate how many enemies we need to spawn
	var total_enemies = 0
	for enemy_type in enemies_to_spawn:
		total_enemies += enemies_to_spawn[enemy_type]
	
	if total_enemies <= 0:
		print("WaveManager: No enemies to spawn in this wave")
		return
	
	# Calculate the time between spawns to distribute over the duration
	var time_between_spawns = duration / total_enemies
	
	# Ensure minimum spawn interval
	time_between_spawns = max(time_between_spawns, min_spawn_interval)
	
	# Create spawn times distributed over the duration
	for i in range(total_enemies):
		var spawn_time = i * time_between_spawns
		spawn_times.append(spawn_time)
	
	# Randomize the spawn times a bit to make it less predictable
	# But keep them in order
	for i in range(1, spawn_times.size()):
		var jitter = randf_range(-0.2, 0.2) * time_between_spawns
		spawn_times[i] += jitter
		# Ensure they stay in order and above minimum interval
		spawn_times[i] = max(spawn_times[i], spawn_times[i-1] + min_spawn_interval)
	
	# Start the first spawn
	if not spawn_times.is_empty():
		spawn_timer.start(spawn_times[0])
		print("WaveManager: First enemy will spawn in ", spawn_times[0], " seconds")
		print("WaveManager: Scheduled ", spawn_times.size(), " enemy spawns over ", duration, " seconds")
		print("WaveManager: Average time between spawns: ", time_between_spawns, " seconds")

func skip_countdown():
	if countdown_active:
		countdown_active = false
		countdown_timer.stop()
		start_next_wave()
		print("WaveManager: Countdown skipped, starting wave immediately")

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
	# Safety check - make sure the enemy is valid
	if not is_instance_valid(enemy):
		print("WaveManager: Enemy died but instance is no longer valid")
		return
		
	active_enemies -= 1
	enemies_killed += 1
	print("WaveManager: Enemy died, " + str(active_enemies) + " enemies remaining, killed " + str(enemies_killed) + " of " + str(enemies_per_wave))

	# Check if this was a boss enemy
	if is_boss_wave() and enemy == current_boss_enemy:
		print("WaveManager: BOSS DEFEATED! Completing wave immediately.")
		current_boss_enemy = null
		_complete_wave()
		return

	# Check if wave is complete
	if active_enemies <= 0 and enemies_spawned >= enemies_per_wave:
		print("WaveManager: All enemies killed, completing wave")
		_complete_wave()

func _complete_wave():
	print("WaveManager: COMPLETING WAVE " + str(current_wave + 1))
	print("WaveManager: DEBUG - current_wave BEFORE increment: " + str(current_wave))
	
	wave_in_progress = false
	
	# Store the expected next wave
	var expected_next_wave = current_wave + 1
	current_wave += 1
	
	# Safeguard against unexpected jumps
	if current_wave != expected_next_wave:
		print("WaveManager: ERROR - Wave jump detected! Expected: " + str(expected_next_wave) + ", Actual: " + str(current_wave))
		# Force correct progression
		current_wave = expected_next_wave
		print("WaveManager: Corrected to wave: " + str(current_wave))
	
	print("WaveManager: DEBUG - current_wave AFTER increment: " + str(current_wave))
	
	# Stop any active timers
	wave_timer.stop()
	spawn_timer.stop()

	# Calculate how long the wave took
	var wave_duration_actual = Time.get_ticks_msec() / 1000.0 - wave_start_time
	print("WaveManager: Wave " + str(current_wave) + " completed in " + str(wave_duration_actual) + " seconds")
	emit_signal("wave_completed", current_wave)

	# Check if all waves are completed
	if current_wave >= waves.size():
		print("WaveManager: All waves completed!")
		emit_signal("all_waves_completed")
		$"../FixedUIContainer/GameWin".visible = true
		return

	# Start countdown to next wave
	time_to_next_wave = time_between_waves
	countdown_active = true
	countdown_timer.start(time_between_waves)

	print("WaveManager: Next wave in " + str(time_between_waves) + " seconds")
	print("WaveManager: DEBUG - Next wave will be: " + str(current_wave + 1))

func set_paused(paused: bool):
	game_paused = paused
	print("WaveManager: Game paused: ", game_paused)

	# Pause/unpause all timers
	countdown_timer.paused = paused
	wave_timer.paused = paused
	spawn_timer.paused = paused

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

# Check if current wave is a boss wave
func is_boss_wave() -> bool:
	if current_wave < 0 or current_wave >= waves.size():
		return false

	return waves[current_wave].get("is_boss_wave", false)

# Announce boss wave with visual and audio cues
func _announce_boss_wave():
	print("WaveManager: BOSS WAVE ANNOUNCEMENT")

	# Create a boss wave announcement label
	var announcement = Label.new()
	announcement.text = "BOSS WAVE INCOMING!"
	announcement.add_theme_font_size_override("font_size", 48)
	announcement.add_theme_color_override("font_color", Color(1, 0, 0))
	announcement.anchor_left = 0.5
	announcement.anchor_top = 0.5
	announcement.anchor_right = 0.5
	announcement.anchor_bottom = 0.5
	announcement.offset_left = -50
	announcement.offset_top = -50
	announcement.offset_right = 50
	announcement.offset_bottom = 50
	announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Add to scene
	get_tree().root.add_child(announcement)

	# Create a timer to remove the announcement
	var announcement_timer = Timer.new()
	announcement_timer.wait_time = 3.0
	announcement_timer.one_shot = true
	announcement.add_child(announcement_timer)
	announcement_timer.timeout.connect(func(): announcement.queue_free())
	announcement_timer.start()

	# Play a sound if available
	var audio_player = AudioStreamPlayer.new()
	var boss_sound_path = "res://audio/game_complete_music02-199540.mp3"

	if ResourceLoader.exists(boss_sound_path):
		audio_player.stream = load(boss_sound_path)
		get_tree().root.add_child(audio_player)
		audio_player.play()
		
		# Set up auto-cleanup
		audio_player.finished.connect(func(): audio_player.queue_free())

func get_enemies_remaining() -> int:
	return enemies_per_wave - enemies_killed
