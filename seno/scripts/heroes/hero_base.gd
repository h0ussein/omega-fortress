extends CharacterBody2D

# Base hero properties
@export var hero_type: String = "mage"
@export var attack_range: float = 150.0
@export var attack_speed: float = 0.7
@export var fire_scene: PackedScene
@export var health: float = 70
@export var move_speed: float = 90.0
@export var base_cost: int = 200
@export var sell_value_percent: float = 0.7
@export var damage: float = 25.0

var is_paused: bool = false

var target_enemy: Node2D = null
var can_attack: bool = true
var is_moving: bool = false

var is_selected: bool = false
var move_target: Vector2 = Vector2.ZERO
var path: Array = []  # Path for grid-based movement

# Grid-related properties
var grid_position: Vector2 = Vector2(-1, -1)
var grid_system = null

# Pause system variables
var move_queued: bool = false
var queued_move_target: Vector2 = Vector2.ZERO

@onready var animation = $Visuals/AnimatedSprite2D
@onready var attack_timer = $AttackTimer
@onready var attack_area = $Area2D
@onready var collision_shape = $CollisionShape2D
@onready var projectile_spawn_point = $Visuals/ProjectileSpawnPoint  # Reference to spawn point if it exists

signal selected(hero)
signal hero_killed(hero)

func _ready():
	print("Hero: Initializing " + hero_type)
	animation.play("idle")

	attack_timer.wait_time = 1.0 / attack_speed
	print("Hero: Set up attack timer with interval: " + str(attack_timer.wait_time) + "s")
	attack_timer.timeout.connect(_on_attack_timer_timeout)

	print("Hero: Connected area signals")
	attack_area.body_entered.connect(_on_enemy_entered)
	attack_area.body_exited.connect(_on_enemy_exited)

	move_target = global_position

	# Make sure the hero is pickable
	input_pickable = true

	# Connect input event signal
	if input_event.is_connected(_on_input_event):
		input_event.disconnect(_on_input_event)
	input_event.connect(_on_input_event)

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

	print("Hero: Ready!")

func _physics_process(delta):
	# Skip processing if game is paused
	if is_paused:
		return
		
	if path.size() > 0:
		# Move along path
		var next_point = path[0]
		var distance = global_position.distance_to(next_point)
		
		if distance < 5:
			path.remove_at(0)
			if path.size() == 0:
				is_moving = false
				velocity = Vector2.ZERO
				if target_enemy == null:
					play_idle()
				
				# Update grid position when we stop
				if grid_system:
					var new_grid_pos = grid_system.world_to_grid(global_position)
					if new_grid_pos != grid_position:
						grid_system.unregister_hero(grid_position)
						grid_position = new_grid_pos
						grid_system.register_hero(self, grid_position)
						print("Hero: Updated grid position to " + str(grid_position))
				
				return
		
		is_moving = true
		var direction = (next_point - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		play_move_animation(direction)
		
		# Stop attacking when moving
		if target_enemy:
			print("Hero: Moving, stopping attack cycle")
			stop_attack()
	else:
		# Check if we need to move to target
		var distance = global_position.distance_to(move_target)
		if distance > 5:
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
				play_move_animation(direction)
		else:
			is_moving = false
			velocity = Vector2.ZERO
			if target_enemy == null:
				play_idle()

func play_move_animation(direction: Vector2):
	if animation.animation != "run":
		animation.play("run")

	# Flip sprite based on movement direction
	animation.flip_h = direction.x < 0

func _process(delta):
	# Skip processing if game is paused
	if is_paused:
		return
		
	# If target is no longer valid, clear it
	if target_enemy and not is_instance_valid(target_enemy):
		print("Hero: Target no longer valid")
		target_enemy = null
		print("Hero: No valid target, stopping attacks")
		stop_attack()

	# Only look for enemies if we're not moving
	if not is_moving:
		if target_enemy == null:
			find_closest_enemy()
		
		if target_enemy and can_attack:
			print("Hero: Starting attack cycle")
			play_attack()
			attack()
	else:
		# We're moving, so we shouldn't be attacking
		if animation.animation == "attack1":
			print("Hero: Stopping attack cycle")
			stop_attack()

func find_closest_enemy():
	var closest_enemy = null
	var min_distance = attack_range

	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			# Skip enemies that are dying
			if body.has_method("is_dying") and body.is_dying:
				continue
				
			var distance = global_position.distance_to(body.global_position)
			if distance <= min_distance:
				min_distance = distance
				closest_enemy = body

	if closest_enemy and closest_enemy != target_enemy:
		print("Hero: Found new target enemy")
		target_enemy = closest_enemy
		can_attack = true

func attack():
	if is_paused:
		return
		
	if not target_enemy or not is_instance_valid(target_enemy) or is_moving:
		return

	# Skip enemies that are dying
	if target_enemy.has_method("is_dying") and target_enemy.is_dying:
		target_enemy = null
		stop_attack()
		return

	print("Hero: Performing attack")
	can_attack = false
	attack_timer.start()

	# Create a timer for when the projectile should be created
	var projectile_timer = get_tree().create_timer(0.3)
	projectile_timer.timeout.connect(create_projectile)

func create_projectile():
	if not target_enemy or not is_instance_valid(target_enemy) or is_moving:
		return
		
	# Skip enemies that are dying
	if target_enemy.has_method("is_dying") and target_enemy.is_dying:
		target_enemy = null
		stop_attack()
		return

	print("Hero: Created projectile")
	var fire = fire_scene.instantiate()

	# Use the spawn point if it exists, otherwise use the hero's position
	var spawn_position = global_position
	if has_node("Visuals/ProjectileSpawnPoint"):
		spawn_position = $Visuals/ProjectileSpawnPoint.global_position
		print("Hero: Using ProjectileSpawnPoint at " + str(spawn_position))
	else:
		# If no spawn point, use a position slightly in front of the hero based on facing direction
		var offset = Vector2(20, -10)  # Default offset for facing right
		if animation.flip_h:
			offset.x = -20  # Flip offset if facing left
		spawn_position = global_position + offset
		print("Hero: Using calculated spawn position at " + str(spawn_position))

	fire.global_position = spawn_position
	fire.target = target_enemy
	fire.damage = damage
	get_parent().add_child(fire)

func stop_attack():
	can_attack = true
	attack_timer.stop()
	play_idle()

func _on_attack_timer_timeout():
	can_attack = true

func _on_enemy_entered(body):
	if is_moving:
		return
		
	if body.is_in_group("enemies") and target_enemy == null:
		# Skip enemies that are dying
		if body.has_method("is_dying") and body.is_dying:
			return
			
		print("Hero: Enemy entered range: " + body.name)
		target_enemy = body
		can_attack = true

func _on_enemy_exited(body):
	if body == target_enemy:
		print("Hero: Target enemy left range")
		target_enemy = null
		stop_attack()

func play_idle():
	if animation.animation != "idle":
		animation.play("idle")

func play_attack():
	if target_enemy:
		animation.flip_h = target_enemy.global_position.x < global_position.x
	if animation.animation != "attack1":
		animation.play("attack1")

func take_damage_hero(amount: float):
	health -= amount
	if health <= 0:
		die()

func die():
	print("hero died!")

	# Unregister from grid
	if grid_system:
		grid_system.unregister_hero(grid_position)

	# Emit signal
	emit_signal("hero_killed", self)

	queue_free()

func get_sell_value() -> int:
	var health_factor = health / 100.0
	return int(base_cost * sell_value_percent * health_factor)

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
		
		# Get the main scene and call its hero selection method directly as a backup
		var main_scene = get_node_or_null("/root/Node2D_main")
		if main_scene and main_scene.has_method("_on_hero_selected"):
			main_scene._on_hero_selected(self)
			print("Hero: Sent selection signal to main scene")

func set_selected(selected: bool):
	is_selected = selected

	if selected:
		modulate = Color(1.2, 1.2, 1.2)
	else:
		modulate = Color(1, 1, 1)

# Get current grid position
func get_grid_position() -> Vector2:
	return grid_position

# Pause system functions
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
