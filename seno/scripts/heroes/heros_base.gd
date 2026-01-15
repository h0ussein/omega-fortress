extends CharacterBody2D

# Base hero properties
@export_category("Hero Stats")
@export var hero_type: String = "base"
@export var max_health: float = 100.0
@export var health: float = 100.0
@export var move_speed: float = 90.0
@export var attack_range: float = 150.0
@export var attack_speed: float = 1.0  # Attacks per second
@export var damage: float = 25.0
@export var base_cost: int = 200
@export var sell_value_percent: float = 0.7

# Visual and audio
@export_category("Visual and Audio")
@export var attack_animation: String = "attack1"
@export var idle_animation: String = "idle"
@export var move_animation: String = "run"
@export var death_animation: String = "die"
@export var hurt_animation: String = "hurt"
@export var hit_sound: AudioStream
@export var attack_sound: AudioStream

# Range indicator properties
@export_category("Range Indicator")
@export var show_range_when_selected: bool = true
@export var range_color: Color = Color(0.2, 0.6, 1.0, 0.3)  # Light blue with transparency

# Combat state
var target_enemy: Node2D = null
var can_attack: bool = true
var is_attacking: bool = false
var attack_cooldown: float = 1.0  # Will be set from attack_speed

# Movement state
var is_moving: bool = false
var is_selected: bool = false
var move_target: Vector2 = Vector2.ZERO
var path: Array = []  # Path for grid-based movement
var stored_velocity: Vector2 = Vector2.ZERO

# Grid-related properties
var grid_position: Vector2 = Vector2(-1, -1)
var grid_system = null

# Game state
var is_paused: bool = false
var is_dying: bool = false
var move_queued: bool = false
var queued_move_target: Vector2 = Vector2.ZERO

# Targeting
enum TargetPriority { CLOSEST, STRONGEST, WEAKEST, FIRST }
@export var target_priority: TargetPriority = TargetPriority.CLOSEST

# Node references
@onready var animation = $Visuals/AnimatedSprite2D
@onready var attack_timer = $AttackTimer
@onready var attack_area = $AttackArea
@onready var health_bar = $HealthBar
@onready var collision_shape = $CollisionShape2D
@onready var audio_player = $AudioPlayer
@onready var range_indicator = null  # Will be created in _ready

# Signals
signal selected(hero)
signal hero_killed(hero)
signal health_changed(current_health, max_health)
signal attack_performed(target)

# Add this near the top of the file with other @export variables
#@export var max_health: float = 70.0

# Then modify the _ready function to initialize health to max_health
func _ready():
	print("Hero: Initializing " + hero_type)
	
	# Set collision layer and mask
	collision_layer = 1  # Layer 1 for heroes
	collision_mask = 6   # Mask for layers 2 and 3 (excluding heroes on layer 1 and bases on layer 4)
	
	# Initialize health
	health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health

	# Create a floating health bar above the hero
	create_floating_health_bar()
	
	# Set up attack timer
	attack_cooldown = 1.0 / attack_speed
	attack_timer.wait_time = attack_cooldown
	print("Hero: Set up attack timer with interval: " + str(attack_timer.wait_time) + "s")
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	# Connect area signals
	print("Hero: Connected area signals")
	if attack_area:
		attack_area.body_entered.connect(_on_enemy_entered)
		attack_area.body_exited.connect(_on_enemy_exited)
	else:
		print("Hero: WARNING - attack_area node not found, enemy detection will not work")
	
	# Set initial animation
	if animation:
		animation.play(idle_animation)
	
	# Set initial position
	move_target = global_position
	
	# Make sure the hero is pickable
	input_pickable = true
	
	# Connect input event signal
	if input_event.is_connected(_on_input_event):
		input_event.disconnect(_on_input_event)
	input_event.connect(_on_input_event)
	
	# Add to heroes group
	add_to_group("heroes")
	
	# Find grid system
	grid_system = get_node_or_null("/root/Node2D_main/GridSystem")
	if grid_system:
		# Register with grid
		grid_position = grid_system.world_to_grid(global_position)
		grid_system.register_hero(self, grid_position)
		print("Hero: Registered with grid at position " + str(grid_position))
	
	# Remove any existing hero panel
	var hero_panel = get_node_or_null("HeroPanel")
	if hero_panel:
		hero_panel.queue_free()
		print("Hero: Removed existing HeroPanel")
	
	# Create range indicator
	create_range_indicator()
	
	print("Hero: Ready!")

# Create a range indicator to show attack range
func create_range_indicator():
	# Check if we already have a range indicator
	if get_node_or_null("RangeIndicator") != null:
		range_indicator = get_node("RangeIndicator")
		return
	
	# Create a new Node2D for the range indicator
	range_indicator = Node2D.new()
	range_indicator.name = "RangeIndicator"
	range_indicator.z_index = -1  # Place below the hero
	add_child(range_indicator)
	
	# Connect draw signal
	range_indicator.draw.connect(_on_range_indicator_draw)
	
	# Hide by default
	range_indicator.visible = false
	
	print("Hero: Created range indicator")

# Draw the range indicator
func _on_range_indicator_draw():
	if range_indicator == null:
		return
	
	# Get the actual attack range from the AttackArea collision shape
	var actual_range = attack_range  # Default fallback
	
	if has_node("AttackArea") and get_node("AttackArea").has_node("CollisionShape2D"):
		var collision_shape_node = get_node("AttackArea").get_node("CollisionShape2D")
		if collision_shape_node.shape is CircleShape2D:
			actual_range = collision_shape_node.shape.radius
			print("Hero: Using AttackArea CircleShape2D radius: " + str(actual_range))
		elif collision_shape_node.shape is RectangleShape2D:
			# For rectangle shapes, use the average of width and height
			actual_range = (collision_shape_node.shape.extents.x + collision_shape_node.shape.extents.y) / 2
			print("Hero: Using AttackArea RectangleShape2D average extents: " + str(actual_range))
	
	# Set color based on hero type
	var indicator_color = range_color
	
	# Different colors for different hero types
	if hero_type == "archer":
		indicator_color = Color(0.2, 0.8, 0.2, 0.3)  # Green for archers
	elif hero_type == "mage":
		indicator_color = Color(0.8, 0.2, 0.8, 0.3)  # Purple for mages
	elif hero_type == "warrior":
		indicator_color = Color(0.8, 0.2, 0.2, 0.3)  # Red for warriors
	elif hero_type == "healer":
		indicator_color = Color(0.2, 0.9, 0.4, 0.3)  # Bright green for healers
	
	# Draw filled circle
	range_indicator.draw_circle(Vector2.ZERO, actual_range, indicator_color)
	
	# Draw outline
	var outline_color = Color(indicator_color.r, indicator_color.g, indicator_color.b, 0.5)
	range_indicator.draw_arc(Vector2.ZERO, actual_range, 0, 2 * PI, 32, outline_color, 2.0)

# Show the range indicator
func show_range():
	if range_indicator == null:
		create_range_indicator()
	
	range_indicator.visible = true
	range_indicator.queue_redraw()  # Force redraw to update the circle

# Hide the range indicator
func hide_range():
	if range_indicator != null:
		range_indicator.visible = false

# Create a floating health bar that appears above the hero
func create_floating_health_bar():
	# Check if we already have a floating health bar
	var existing_bar = get_node_or_null("FloatingHealthBar")
	if existing_bar:
		existing_bar.queue_free()
	
	# Create a new Control node for the health bar
	var floating_health_bar_container = Control.new()
	floating_health_bar_container.name = "FloatingHealthBar"
	floating_health_bar_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	floating_health_bar_container.position = Vector2(0, -30)  # Position above the hero
	floating_health_bar_container.custom_minimum_size = Vector2(60, 10)
	floating_health_bar_container.size = Vector2(30, 10)
	
	# Create the background of the health bar
	var background = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray, semi-transparent
	background.size = Vector2(30, 10)
	background.position = Vector2(-30, 0)  # Center horizontally
	floating_health_bar_container.add_child(background)
	
	# Create the foreground (health indicator) of the health bar
	var health_indicator = ColorRect.new()
	health_indicator.name = "Foreground"
	health_indicator.color = Color(0.2, 0.8, 0.2, 0.9)  # Green, mostly opaque
	health_indicator.size = Vector2(30, 10)
	health_indicator.position = Vector2(-30, 0)  # Center horizontally
	floating_health_bar_container.add_child(health_indicator)
	
	# Create a border for the health bar
	var border = ColorRect.new()
	border.name = "Border"
	border.color = Color(0, 0, 0, 0)  # Transparent
	border.size = Vector2(32, 12)
	border.position = Vector2(-31, -1)  # Slightly larger than the background
	
	# Add a stylebox to create a border effect
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0)  # Transparent background
	style_box.border_width_left = 1
	style_box.border_width_top = 1
	style_box.border_width_right = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(0, 0, 0, 0.5)  # Black, semi-transparent
	style_box.corner_radius_top_left = 2
	style_box.corner_radius_top_right = 2
	style_box.corner_radius_bottom_right = 2
	style_box.corner_radius_bottom_left = 2
	
	border.add_theme_stylebox_override("panel", style_box)
	floating_health_bar_container.add_child(border)
	
	# Create a label for displaying health value
	var health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.text = str(int(health)) + "/" + str(int(max_health))
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_label.size = Vector2(60, 10)
	health_label.position = Vector2(-30, 0)  # Center horizontally
	
	# Add outline to make text more readable
	health_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))  # White text
	health_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))  # Black outline
	health_label.add_theme_constant_override("outline_size", 1)
	health_label.add_theme_font_size_override("font_size", 8)  # Smaller font size
	
	floating_health_bar_container.add_child(health_label)
	
	# Add the health bar container to the hero
	add_child(floating_health_bar_container)
	
	# Update the health bar to reflect current health
	update_floating_health_bar()
	
	print("Hero: Created floating health bar")

# Update the floating health bar to reflect current health
func update_floating_health_bar():
	var floating_health_bar_container = get_node_or_null("FloatingHealthBar")
	if not floating_health_bar_container:
		return
		
	var health_indicator = floating_health_bar_container.get_node_or_null("Foreground")
	var health_label = floating_health_bar_container.get_node_or_null("HealthLabel")
	
	if health_indicator:
		# Calculate health percentage
		var health_percent = health / max_health
		
		# Update foreground width based on health percentage
		health_indicator.size.x = 60 * health_percent
		
		# Update foreground color based on health percentage
		if health_percent > 0.6:
			health_indicator.color = Color(0.2, 0.8, 0.2, 0.9)  # Green
		elif health_percent > 0.3:
			health_indicator.color = Color(0.8, 0.8, 0.2, 0.9)  # Yellow
		else:
			health_indicator.color = Color(0.8, 0.2, 0.2, 0.9)  # Red
	
	if health_label:
		# Update health text
		health_label.text = str(int(health)) + "/" + str(int(max_health))

func _physics_process(delta):
	# Skip processing if game is paused or hero is dying
	if is_paused or is_dying:
		return
	
	# Handle path-based movement
	if path.size() > 0:
		_follow_path()
	else:
		# Check if we need to move to target
		var distance = global_position.distance_to(move_target)
		if distance > 5:
			_handle_movement()
		else:
			is_moving = false
			velocity = Vector2.ZERO
			if target_enemy == null and animation:
				animation.play(idle_animation)

func _process(delta):
	# Skip processing if game is paused or hero is dying
	if is_paused or is_dying:
		return
	
	# If target is no longer valid, clear it
	if target_enemy and not is_instance_valid(target_enemy):
		target_enemy = null
		stop_attack()
	
	# Only look for enemies if we're not moving
	if not is_moving:
		if target_enemy == null:
			find_target_enemy()
		
		if target_enemy and can_attack:
			start_attack()
	else:
		# We're moving, so we shouldn't be attacking
		if is_attacking:
			stop_attack()

# Movement methods
func _follow_path():
	if path.size() == 0:
		return
	
	var next_point = path[0]
	var distance = global_position.distance_to(next_point)
	
	if distance < 5:
		path.remove_at(0)
		if path.size() == 0:
			is_moving = false
			velocity = Vector2.ZERO
			if target_enemy == null and animation:
				animation.play(idle_animation)
			
			# Update grid position when we stop
			_update_grid_position()
			return
	
	is_moving = true
	var direction = (next_point - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()
	
	if animation:
		animation.play(move_animation)
		# Flip sprite based on movement direction
		animation.flip_h = direction.x < 0
	
	# Stop attacking when moving
	if is_attacking:
		stop_attack()

func _handle_movement():
	# Get path to target
	if grid_system:
		var target_grid_pos = grid_system.world_to_grid(move_target)
		var start_grid_pos = grid_system.world_to_grid(global_position)
		
		print("Hero: Finding path from " + str(start_grid_pos) + " to " + str(target_grid_pos))
		
		# Check if target is in green zone
		if not grid_system.is_in_green_zone(target_grid_pos):
			print("Hero: Cannot move outside green zone to " + str(target_grid_pos))
			move_target = global_position  # Reset target to current position
			return
		
		# Find path (respecting green zone)
		var grid_path = grid_system.find_path_for_hero(start_grid_pos, target_grid_pos)
		
		# Convert to world positions
		path.clear()
		for pos in grid_path:
			path.append(grid_system.grid_to_world(pos))
		
		# Add final target position if needed
		if path.size() == 0 or path[path.size() - 1].distance_to(move_target) > 5:
			path.append(move_target)
		
		print("Hero: Found path with " + str(path.size()) + " points")
		
		# If path is empty, we can't reach the target
		if path.size() == 0:
			print("Hero: Could not find path to target")
			move_target = global_position  # Reset target to current position
			return
	else:
		# Fallback to direct movement if no grid system
		is_moving = true
		var direction = (move_target - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		
		if animation:
			animation.play(move_animation)
			animation.flip_h = direction.x < 0

func _update_grid_position():
	if grid_system:
		var new_grid_pos = grid_system.world_to_grid(global_position)
		if new_grid_pos != grid_position:
			grid_system.unregister_hero(grid_position)
			grid_position = new_grid_pos
			grid_system.register_hero(self, grid_position)
			print("Hero: Updated grid position to " + str(grid_position))

# Combat methods
func find_target_enemy():
	var potential_targets = []
	
	# Check if attack_area exists
	if not attack_area or not is_instance_valid(attack_area):
		print("Hero: ERROR - attack_area is null or invalid")
		return
	
	# Collect all valid enemies in range
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			# Skip enemies that are dying
			if body.has_method("is_dying") and body.is_dying:
				continue
				
			var distance = global_position.distance_to(body.global_position)
			if distance <= attack_range:
				potential_targets.append(body)
	
	if potential_targets.size() == 0:
		return
	
	# Sort based on targeting priority
	match target_priority:
		TargetPriority.CLOSEST:
			potential_targets.sort_custom(func(a, b): 
				return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
		
		TargetPriority.STRONGEST:
			potential_targets.sort_custom(func(a, b): 
				return a.health > b.health)
		
		TargetPriority.WEAKEST:
			potential_targets.sort_custom(func(a, b): 
				return a.health < b.health)
		
		TargetPriority.FIRST:
			# This would require tracking when enemies spawned or their progress along the path
			# For now, we'll just use closest as a fallback
			potential_targets.sort_custom(func(a, b): 
				return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	
	if potential_targets.size() > 0:
		target_enemy = potential_targets[0]
		print("Hero: Found new target enemy: " + str(target_enemy.name))

func start_attack():
	if is_paused or is_moving or is_dying:
		return
	
	is_attacking = true
	
	# Face the enemy
	if animation and target_enemy:
		animation.flip_h = target_enemy.global_position.x < global_position.x
	
	# Play attack animation
	if animation:
		animation.play(attack_animation)
	
	# Perform the attack
	perform_attack()
	
	# Start cooldown
	can_attack = false
	attack_timer.start()

func perform_attack():
	# This is the base attack method that should be overridden by child classes
	if not target_enemy or not is_instance_valid(target_enemy):
		return
	
	# Skip enemies that are dying
	if target_enemy.has_method("is_dying") and target_enemy.is_dying:
		target_enemy = null
		stop_attack()
		return
	
	print("Hero: Performing attack")
	
	# Play attack sound
	if audio_player and attack_sound:
		audio_player.stream = attack_sound
		audio_player.play()
	
	# Deal damage to the enemy
	if target_enemy.has_method("take_damage"):
		target_enemy.take_damage(damage)
	
	# Emit signal
	emit_signal("attack_performed", target_enemy)

func stop_attack():
	is_attacking = false
	can_attack = true
	attack_timer.stop()
	
	if animation and not is_moving:
		animation.play(idle_animation)

func _on_attack_timer_timeout():
	can_attack = true

func _on_enemy_entered(body):
	if is_moving or is_dying or not attack_area:
		return
	
	if body.is_in_group("enemies") and target_enemy == null:
		# Skip enemies that are dying
		if body.has_method("is_dying") and body.is_dying:
			return
			
		print("Hero: Enemy entered range: " + body.name)
		target_enemy = body
		can_attack = true

func _on_enemy_exited(body):
	if not attack_area:
		return
		
	if body == target_enemy:
		print("Hero: Target enemy left range")
		target_enemy = null
		stop_attack()

# Health and damage methods
func take_damage(amount: float):
	# Skip damage if paused or dying
	if is_paused or is_dying:
		return

	# If amount is negative, it's healing
	if amount < 0:
		heal(-amount)  # Convert negative damage to positive healing
		return
		
	print("Hero: Taking damage: " + str(amount))
	health -= amount

	# Update health bar
	if health_bar:
		health_bar.value = health
	
	# Update floating health bar
	update_floating_health_bar()

	# Emit signal
	emit_signal("health_changed", health, max_health)

	# Play hit sound
	if audio_player and hit_sound:
		audio_player.stream = hit_sound
		audio_player.play()

	if health <= 0:
		die()
	else:
		# Play hurt animation if available
		if animation and animation.sprite_frames and animation.sprite_frames.has_animation(hurt_animation):
			# Store current animation to return to it after hurt animation
			var previous_animation = animation.animation
			
			# Play hurt animation
			animation.play(hurt_animation)
			
			# Wait for hurt animation to finish
			await animation.animation_finished
			
			# Return to previous animation if not moving or attacking
			if not is_moving and not is_attacking:
				animation.play(previous_animation)
			elif is_moving:
				animation.play(move_animation)
			elif is_attacking:
				animation.play(attack_animation)

# Add a dedicated healing method
func heal(amount: float):
	if is_dying or is_paused:
		return
		
	print("Hero: Healing for " + str(amount) + " health")
	health += amount
	
	# Cap health at max_health
	if health > max_health:
		health = max_health
		
	# Update health bar
	if health_bar:
		health_bar.value = health
	
	# Update floating health bar
	update_floating_health_bar()
	
	# Emit signal
	emit_signal("health_changed", health, max_health)
	
	print("Hero: Health after healing: " + str(health) + "/" + str(max_health))

func die():
	if is_dying:
		return
	
	print("Hero: " + hero_type + " died!")
	is_dying = true
	
	# Stop all movement and attacks
	velocity = Vector2.ZERO
	is_moving = false
	stop_attack()
	
	# Hide range indicator
	hide_range()
	
	# Play death animation if available
	if animation and animation.sprite_frames and animation.sprite_frames.has_animation(death_animation):
		print("Hero: Playing death animation")
		
		# Ensure the animation doesn't loop
		var was_looping = false
		if animation.sprite_frames.get_animation_loop(death_animation):
			was_looping = true
			# We can't modify the sprite frames at runtime, so we'll handle this differently
			print("Hero: Death animation was set to loop, will handle manually")
		
		animation.play(death_animation)
		
		# Wait for animation to finish
		if was_looping:
			# If animation was set to loop, we'll wait for one cycle manually
			await get_tree().create_timer(animation.sprite_frames.get_frame_count(death_animation) / animation.sprite_frames.get_animation_speed(death_animation)).timeout
			print("Hero: Manually waited for looping death animation")
		else:
			# Otherwise wait for the animation_finished signal
			await animation.animation_finished
			print("Hero: Death animation finished")
	else:
		print("Hero: No death animation available")
	
	# Unregister from grid
	if grid_system:
		print("Hero: Unregistering from grid at position " + str(grid_position))
		grid_system.unregister_hero(grid_position)
		# Explicitly mark the cell as empty
		grid_system.set_cell_empty(grid_position)
	
	# Emit signal
	emit_signal("hero_killed", self)
	
	print("Hero: Removing from scene")
	# Remove from scene
	queue_free()

func get_sell_value() -> int:
	var health_factor = health / max_health
	return int(base_cost * sell_value_percent * health_factor)

# Input and selection methods
func is_mouse_over() -> bool:
	var mouse_pos = get_global_mouse_position()
	
	# Use a larger detection area to make selection easier
	var detection_radius = 40.0  # Increased from 32.0 for easier selection
	var distance = global_position.distance_to(mouse_pos)
	
	if distance <= detection_radius:
		return true
	
	# If we have a collision shape, use it for more precise detection
	if collision_shape and is_instance_valid(collision_shape) and collision_shape.shape:
		var shape_extents = collision_shape.shape.extents if collision_shape.shape is RectangleShape2D else Vector2(40, 40)
		var rect = Rect2(global_position - shape_extents, shape_extents * 2)
		if rect.has_point(mouse_pos):
			return true
	
	# Fallback to physics query
	var space_state = get_world_2d().direct_space_state
	if space_state:
		var query = PhysicsPointQueryParameters2D.new()
		query.position = mouse_pos
		query.collision_mask = collision_mask
		var result = space_state.intersect_point(query)
		
		for item in result:
			if item.collider == self:
				return true
	
	return false

func _on_input_event(viewport, event, shape_idx):
	print("Hero: Input event received: " + str(event))
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Hero clicked!")
		is_selected = true
		emit_signal("selected", self)
		
		# Show range indicator when selected
		if show_range_when_selected:
			show_range()
		
		# Get the main scene and call its hero selection method directly as a backup
		var main_scene = get_node_or_null("/root/Node2D_main")
		if main_scene and main_scene.has_method("_on_hero_selected"):
			main_scene._on_hero_selected(self)
			print("Hero: Sent selection signal to main scene")

func set_selected(selected: bool):
	is_selected = selected
	
	if selected:
		modulate = Color(1.2, 1.2, 1.2)  # Slightly brighter when selected
		
		# Show range indicator when selected
		if show_range_when_selected:
			show_range()
	else:
		modulate = Color(1, 1, 1)  # Normal color when not selected
		
		# Hide range indicator when deselected
		hide_range()

# Get current grid position
func get_grid_position() -> Vector2:
	return grid_position

# Set movement target
func set_move_target(target_position: Vector2):
	# Get main scene to check if game is paused
	var main_scene = get_node_or_null("/root/Node2D_main")
	if main_scene and main_scene.game_paused:
		# Store the move target for when game resumes
		move_queued = true
		queued_move_target = target_position
		print("Hero: Move queued to " + str(target_position))
	else:
		# Execute move immediately
		move_target = target_position
		print("Hero: Move target set to " + str(target_position))

# Set targeting priority
func set_target_priority(priority: TargetPriority):
	target_priority = priority
	# Clear current target to force re-evaluation with new priority
	target_enemy = null

# Pause handling
func set_paused(paused: bool):
	is_paused = paused
	
	# If paused, stop all movement and animations
	if is_paused:
		# Store current velocity to restore later
		if is_moving:
			stored_velocity = velocity
			velocity = Vector2.ZERO
		
		# Pause animations
		if animation:
			animation.pause()
		
		# Pause any active timers
		if attack_timer:
			attack_timer.paused = true
		
		# Hide range indicator when paused
		hide_range()
		
		# Find and pause all animation players
		for child in get_children():
			if child is AnimationPlayer:
				child.pause()
	else:
		# Resume animations
		if animation:
			animation.play()
		
		# Resume timers
		if attack_timer:
			attack_timer.paused = false
		
		# Show range indicator if selected and unpaused
		if is_selected and show_range_when_selected:
			show_range()
		
		# Find and resume all animation players
		for child in get_children():
			if child is AnimationPlayer:
				child.play()
		
		# Restore movement if we were moving
		if is_moving and stored_velocity != Vector2.ZERO:
			velocity = stored_velocity
	
	# Execute queued move if unpausing
	if not paused and move_queued:
		move_target = queued_move_target
		move_queued = false
		print("Hero: Executing queued move to " + str(move_target))

# Add a dedicated method for taking damage from projectiles
func take_damage_hero(amount: float):
	print("Hero: Taking projectile damage: " + str(amount))
	take_damage(amount)  # Use the existing take_damage method
