extends CharacterBody2D

# Base properties for all enemies
@export var move_speed: float = 70.0
@export var health: float = 200.0
@export var max_health: float = 200.0
@export var damage: float = 20.0
@export var attack_range: float = 20.0
@export var attack_cooldown: float = 1.0
@export var gold_value: int = 20  # Gold awarded when killed

# Movement smoothing
@export var movement_smoothing: bool = true
@export var path_arrival_threshold: float = 5.0  # Distance to consider a point reached
@export var look_ahead_points: int = 2  # Number of points to look ahead for smoother turning
@export var turn_smoothing: float = 0.2  # Lower = sharper turns, higher = smoother turns

# Pathfinding variables
var target: Node2D = null
var path: Array = []
var grid_system = null
var grid_position: Vector2 = Vector2(-1, -1)
var current_path_index: int = 0

# Path recalculation optimization
var path_update_interval: float = 3.0  # Using the 3.0 second interval from the old code
var path_update_timer: Timer = null
var path_finding_in_progress: bool = false  # Flag to prevent multiple pathfinding calls

# Attack state
var is_attacking: bool = false
var can_attack: bool = true
var is_dying: bool = false  # Add dying state flag

# Status effects
var is_slowed: bool = false
var slow_amount: float = 0.0
var slow_duration: float = 0.0
var slow_timer: Timer = null
var original_speed: float = 0.0

# Pause state
var is_paused: bool = false
var stored_velocity: Vector2 = Vector2.ZERO

# Common components
@onready var health_bar = $HealthBar
@onready var animation_player = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var animated_sprite = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null

signal died(enemy)

func _ready():
	# Add to enemies group
	add_to_group("enemies")

	# Store original speed for reference
	original_speed = move_speed

	# Initialize health display
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	else:
		# Create health bar if it doesn't exist
		create_health_bar()

	# Find the base as the initial target
	var bases = get_tree().get_nodes_in_group("base")
	if bases.size() > 0:
		target = bases[0]

	# Find the grid system
	grid_system = get_node_or_null("/root/Node2D_main/GridSystem")
	if grid_system:
		grid_position = grid_system.world_to_grid(global_position)
		# Register with grid
		grid_system.register_enemy(self, grid_position)
		print("Enemy: Found grid system and set initial position to " + str(grid_position))

	# Create path update timer (using the approach from the old code)
	path_update_timer = Timer.new()
	path_update_timer.wait_time = path_update_interval
	path_update_timer.one_shot = false
	path_update_timer.autostart = true
	path_update_timer.timeout.connect(update_path)
	add_child(path_update_timer)

	# Create slow effect timer
	slow_timer = Timer.new()
	slow_timer.one_shot = true
	slow_timer.timeout.connect(_on_slow_timer_timeout)
	add_child(slow_timer)
	
	# Debug collision layers
	print("Enemy: Collision layer: " + str(collision_layer))
	print("Enemy: Collision mask: " + str(collision_mask))
	
	# Make sure we're in the enemies group
	if not is_in_group("enemies"):
		add_to_group("enemies")
		print("Enemy: Added to enemies group")

	# Initial path update
	call_deferred("update_path")  # Use call_deferred to ensure the scene is fully loaded

func create_health_bar():
	# Create a ProgressBar node for the health bar
	var new_health_bar = ProgressBar.new()
	new_health_bar.name = "HealthBar"
	
	# Set size and position
	new_health_bar.custom_minimum_size = Vector2(30, 5)
	new_health_bar.position = Vector2(-15, -30)  # Position above the enemy
	
	# Set up the health bar properties
	new_health_bar.max_value = max_health
	new_health_bar.value = health
	new_health_bar.show_percentage = false
	
	# Style the health bar
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.8, 0.2)  # Green
	style_box.corner_radius_top_left = 1
	style_box.corner_radius_top_right = 1
	style_box.corner_radius_bottom_right = 1
	style_box.corner_radius_bottom_left = 1
	new_health_bar.add_theme_stylebox_override("fill", style_box)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray background
	bg_style.corner_radius_top_left = 1
	bg_style.corner_radius_top_right = 1
	bg_style.corner_radius_bottom_right = 1
	bg_style.corner_radius_bottom_left = 1
	new_health_bar.add_theme_stylebox_override("background", bg_style)
	
	# Add the health bar to the enemy
	add_child(new_health_bar)
	health_bar = new_health_bar
	
	print("Enemy: Created health bar")

func _physics_process(delta):
	# Skip if dying or paused
	if is_dying or is_paused:
		return
	
	# Base movement logic - can be overridden by child classes
	if target and is_instance_valid(target):
		var distance_to_target = global_position.distance_to(target.global_position)
		
		# Move along path if not in attack range
		if distance_to_target > attack_range:
			move_along_path(delta)

	move_and_slide()

	# Update grid position if moved
	if grid_system and not is_dying:
		var new_grid_pos = grid_system.world_to_grid(global_position)
		if new_grid_pos != grid_position:
			grid_system.unregister_enemy(grid_position)
			grid_position = new_grid_pos
			grid_system.register_enemy(self, grid_position)

# Simplified movement logic from the old code
func move_along_path(delta):
	if is_dying or is_paused:
		return

	if path.size() > 0:
		var next_point = path[0]
		var distance = global_position.distance_to(next_point)
		
		if distance < path_arrival_threshold:
			path.remove_at(0)
			if path.size() == 0:
				# If we've reached the end of the path but not the target,
				# request a new path immediately
				if target and is_instance_valid(target):
					update_path()
				return
			next_point = path[0]
		
		var direction = (next_point - global_position).normalized()
		
		# Apply slow effect if active
		var current_speed = move_speed
		if is_slowed:
			current_speed = move_speed * (1.0 - slow_amount)
		
		velocity = direction * current_speed
	else:
		# Direct movement if no path
		if target and is_instance_valid(target) and not path_finding_in_progress:
			var direction = (target.global_position - global_position).normalized()
			
			# Apply slow effect if active
			var current_speed = move_speed
			if is_slowed:
				current_speed = move_speed * (1.0 - slow_amount)
			
			velocity = direction * current_speed * 0.5  # Move slower when no path

# Apply slow effect to the enemy
func apply_slow(amount: float, duration: float):
	# Skip if paused
	if is_paused:
		return
		
	# Store the original speed if this is a new slow effect
	if not is_slowed:
		original_speed = move_speed
	
	# Apply the strongest slow effect
	if amount > slow_amount:
		slow_amount = amount
		print("Enemy: Slowed by " + str(slow_amount * 100) + "% for " + str(duration) + " seconds")
	
	# Set or extend the duration
	slow_duration = max(slow_duration, duration)
	is_slowed = true
	
	# Update visual indication of being slowed
	modulate = Color(0.7, 0.9, 1.0)  # Light blue tint
	
	# Reset and start the timer
	slow_timer.stop()
	slow_timer.wait_time = slow_duration
	slow_timer.start()

# Called when slow effect expires
func _on_slow_timer_timeout():
	is_slowed = false
	slow_amount = 0.0
	slow_duration = 0.0
	
	# Reset visual indication
	modulate = Color(1, 1, 1)  # Normal color
	
	print("Enemy: Slow effect expired")

# Update path using the approach from the old code
func update_path():
	if is_dying or path_finding_in_progress or is_paused:
		return
	
	if not target or not is_instance_valid(target):
		return

	path_finding_in_progress = true

	# Use the grid system to find a path
	if grid_system and grid_system.has_method("find_path_for_enemy"):
		var start_time = Time.get_ticks_msec()
		var new_path = grid_system.find_path_for_enemy(self)
		var end_time = Time.get_ticks_msec()
		
		if new_path.size() > 0:
			path = new_path
			print("Enemy found path with " + str(path.size()) + " points in " + str(end_time - start_time) + "ms")
		else:
			print("Enemy could not find path to target!")
			
			# Fallback to direct movement if no path found
			if target and is_instance_valid(target):
				var direct_point = target.global_position
				path = [direct_point]
				print("Enemy using direct path to target as fallback")
	else:
		# Fallback to direct movement if no grid system
		if target and is_instance_valid(target):
			var direct_point = target.global_position
			path = [direct_point]
			print("Enemy using direct path to target (no grid system)")

	path_finding_in_progress = false

# Get current path for debugging
func get_current_path() -> Array:
	return path

# Base attack methods - can be overridden by child classes
func start_attack():
	if is_paused:
		return
		
	is_attacking = true
	can_attack = false

func perform_attack():
	if is_paused:
		return
		
	if target and target.has_method("take_damage"):
		target.take_damage(damage)
	can_attack = true

func take_damage(amount: float):
	if is_dying or is_paused:
		return  # Don't take damage if already dying or paused
	
	health -= amount

	# Update health bar
	if health_bar:
		health_bar.value = health
		
		# Update health bar color based on health percentage
		var health_percent = health / max_health
		var style_box = health_bar.get_theme_stylebox("fill", "")
		
		if style_box is StyleBoxFlat:
			if health_percent > 0.6:
				style_box.bg_color = Color(0.2, 0.8, 0.2)  # Green
			elif health_percent > 0.3:
				style_box.bg_color = Color(0.9, 0.7, 0.1)  # Yellow/Orange
			else:
				style_box.bg_color = Color(0.9, 0.2, 0.2)  # Red
	
	# Visual feedback for taking damage
	flash_damage()

	if health <= 0:
		die()

func flash_damage():
	# Flash red when taking damage
	modulate = Color(1.5, 0.5, 0.5)  # Red tint
	
	# Create a tween to restore normal color
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.3)
	
	# If slowed, restore to the slow tint
	if is_slowed:
		tween.tween_property(self, "modulate", Color(0.7, 0.9, 1.0), 0.1)

func die():
	if is_dying:
		return  # Prevent multiple death calls

	print("Enemy died!")
	is_dying = true

	# Stop all movement
	velocity = Vector2.ZERO

	# Stop path updates
	if path_update_timer:
		path_update_timer.stop()

	# Stop slow timer
	if slow_timer:
		slow_timer.stop()

	# Disable collision
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)

	# Remove from enemies group so heroes stop targeting
	remove_from_group("enemies")

	# Unregister from grid
	if grid_system:
		grid_system.unregister_enemy(grid_position)

	# Emit died signal
	emit_signal("died", self)

	# Give gold to player
	var main_scene = get_node_or_null("/root/Node2D_main")
	if main_scene and is_instance_valid(main_scene):
		main_scene.gold += gold_value
		main_scene.update_gold_display()
		print("Enemy: Gave " + str(gold_value) + " gold to player")
	
	# Play death animation or effect
	show_death_effect()

func show_death_effect():
	# Hide the health bar
	if health_bar:
		health_bar.visible = false
	
	# Create death particles
	var particles = CPUParticles2D.new()
	particles.name = "DeathParticles"
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = 20
	particles.lifetime = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.gravity = Vector2(0, 98)
	particles.initial_velocity_min = 30
	particles.initial_velocity_max = 80
	particles.scale_amount_min = 2
	particles.scale_amount_max = 4
	particles.color = Color(0.8, 0.2, 0.2)  # Red color for enemy death
	add_child(particles)
	
	# Fade out the enemy
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(queue_free)

func apply_knockback(direction: Vector2, strength: float):
	# Skip if dying or paused
	if is_dying or is_paused:
		return
		
	print("Enemy: Applying knockback with strength " + str(strength))
	
	# Apply impulse in the given direction
	velocity += direction * strength

# Pause handling
# Ensure the base enemy class properly handles animation pausing
func set_paused(paused: bool):
	is_paused = paused
	
	# If paused, store current velocity and stop movement
	if is_paused:
		stored_velocity = velocity
		velocity = Vector2.ZERO
		
		# Pause timers
		if path_update_timer:
			path_update_timer.paused = true
		if slow_timer:
			slow_timer.paused = true
		
		# Pause animations
		if animation_player:
			animation_player.pause()
		if animated_sprite:
			animated_sprite.pause()
		
		# Find and pause all animation players and animated sprites in children
		_pause_all_animations(self, true)
	else:
		# Resume movement
		velocity = stored_velocity
		
		# Resume timers
		if path_update_timer:
			path_update_timer.paused = false
		if slow_timer:
			slow_timer.paused = false
		
		# Resume animations
		if animation_player:
			animation_player.play()
		if animated_sprite:
			animated_sprite.play()
		
		# Find and resume all animation players in children
		_pause_all_animations(self, false)
	
	print("Enemy: Pause state set to " + str(paused))

# Helper function to recursively pause/unpause all animations in a node and its children
func _pause_all_animations(node: Node, should_pause: bool):
	if node is AnimationPlayer:
		if should_pause:
			node.pause()
		else:
			node.play()
	elif node is AnimatedSprite2D:
		if should_pause:
			node.pause()
		else:
			node.play()
	
	# Recursively process all children
	for child in node.get_children():
		_pause_all_animations(child, should_pause)

# Add these stub methods to your grid_system.gd script
# Place them anywhere in the script, preferably near the end

# Stub method for enemy registration - does nothing but prevents errors
func register_enemy(enemy, grid_pos):
	# This is just a stub to prevent errors
	# No actual registration happens
	pass

# Stub method for enemy unregistration - does nothing but prevents errors
func unregister_enemy(grid_pos):
	# This is just a stub to prevent errors
	# No actual unregistration happens
	pass
