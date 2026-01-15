extends "res://scripts/enemies/enemy_base.gd"

# Your specific enemy properties
@export var speed: float = 100.0
@export var attack_damage: float = 20.0
@export var attack_interval: float = 1.0

var target_base: Node2D
var target_hero: Node2D = null
var local_original_speed: float = 0.0  # Local variable to store original speed
# Using is_dying from parent class

@onready var attack_hero_timer = $AttackHero
@onready var attack_base_timer = $AttackBase
@onready var animation = $Visuals/AnimatedSprite2D
@onready var attack_area = $AttackArea  # Make sure this matches your scene structure

func _ready():
	# Set base class properties from your properties
	move_speed = speed
	damage = attack_damage
	attack_cooldown = attack_interval
	
	# Set max_health for enemy3 specifically
	max_health = 300.0  # Set the max health for enemy_3 (more health than enemy1)
	health = max_health  # Initialize health to max_health

	local_original_speed = speed  # Store the original speed locally
	target_base = get_tree().get_first_node_in_group("base")
	target = target_base  # Set the base class target

	# Initialize timers and animations
	if animation:
		animation.play("run")

	# Check if timers exist before setting them up
	if attack_hero_timer:
		attack_hero_timer.wait_time = attack_interval
		attack_hero_timer.timeout.connect(_on_attack_hero_timeout)
	else:
		print("ERROR: AttackHero timer not found!")
	
	if attack_base_timer:
		attack_base_timer.wait_time = attack_interval
		attack_base_timer.timeout.connect(_on_attack_base_timeout)
	else:
		print("ERROR: AttackBase timer not found!")

	# Connect area signals with null check
	if attack_area:
		print("Enemy: Connected area signals")
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)
	else:
		print("ERROR: AttackArea area not found!")

	# Call parent _ready to set up pathfinding
	super._ready()
	
	# Make sure health bar is properly initialized with our max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	else:
		# Create health bar if it doesn't exist
		create_health_bar()
		
	print("Enemy3: Ready with health: " + str(health) + "/" + str(max_health))

# Create a health bar for the enemy
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
	
	print("Enemy3: Created health bar")

# Override the physics process to use your movement logic
func _physics_process(delta):
	# Skip if dying or paused
	if is_dying or is_paused:
		return  # Return immediately without doing anything when paused

	# Skip parent physics process and implement our own
	if target_hero and is_instance_valid(target_hero):
		# Stop moving and face the hero when attacking
		velocity = Vector2.ZERO
		$Visuals.scale.x = sign(target_hero.global_position.x - global_position.x)
	elif target_base and is_instance_valid(target_base):
		# Use pathfinding if we have a path
		if path.size() > 0:
			move_along_path(delta)
			# Update visuals based on movement direction
			if velocity.length() > 0:
				$Visuals.scale.x = -1 if velocity.x > 0 else 1
		else:
			# Fallback to direct movement if no path
			var direction = global_position.direction_to(target_base.global_position)
			
			# Calculate current speed based on parent class variables
			var current_speed = move_speed
			if is_slowed:
				current_speed = move_speed * (1.0 - slow_amount)
			
			velocity = direction * current_speed
			$Visuals.scale.x = -1 if direction.x > 0 else 1
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	# Update grid position if moved (from parent class)
	if grid_system and not is_dying:
		var new_grid_pos = grid_system.world_to_grid(global_position)
		if new_grid_pos != grid_position:
			grid_system.unregister_enemy(grid_position)
			grid_position = new_grid_pos
			grid_system.register_enemy(self, grid_position)

func _on_attack_base_timeout():
	if is_dying or is_paused:
		return
	
	if target_base and is_instance_valid(target_base):
		if target_base.has_method("take_damage_base"):
			target_base.take_damage_base(attack_damage)
	else:
		if attack_base_timer:
			attack_base_timer.stop()

func _on_attack_hero_timeout():
	if is_dying or is_paused:
		return
	
	if target_hero and is_instance_valid(target_hero):
		print("Enemy: Attacking hero with timer for " + str(attack_damage) + " damage")
		# Try both methods for compatibility
		if target_hero.has_method("take_damage_hero"):
			target_hero.take_damage_hero(attack_damage)
			print("Enemy: Used take_damage_hero method")
		elif target_hero.has_method("take_damage"):
			target_hero.take_damage(attack_damage)
			print("Enemy: Used take_damage method")
		else:
			print("Enemy: ERROR - Hero doesn't have damage method!")
	else:
		if attack_hero_timer:
			attack_hero_timer.stop()

# Override the take_damage method to use your animation
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

	if health <= 0:
		start_death()
	else:
		# Play hit animation
		if animation:
			animation.play("hit")
			await animation.animation_finished
			# Return to previous animation
			if target_hero and is_instance_valid(target_hero):
				animation.play("attack1")
			else:
				animation.play("run")

func start_death():
	if is_dying:
		return  # Prevent multiple death calls

	is_dying = true

	# Stop all movement
	velocity = Vector2.ZERO
	speed = 0

	# Stop attack timers
	if attack_hero_timer:
		attack_hero_timer.stop()
	if attack_base_timer:
		attack_base_timer.stop()

	# Remove from enemies group so heroes stop targeting
	remove_from_group("enemies")

	# Disable collision
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)

	# Disable attack area
	if attack_area and attack_area.has_node("CollisionShape2D"):
		attack_area.get_node("CollisionShape2D").set_deferred("disabled", true)

	# Unregister from grid
	if grid_system:
		grid_system.unregister_enemy(grid_position)

	# Emit died signal
	emit_signal("died", self)

	# Play death animation
	if animation:
		animation.play("die")
		await animation.animation_finished

	# Give gold to player
	var main_scene = get_node_or_null("/root/Node2D_main")
	if main_scene and is_instance_valid(main_scene):
		main_scene.gold += gold_value
		main_scene.update_gold_display()
		print("Enemy: Gave " + str(gold_value) + " gold to player")

	# Remove from scene
	queue_free()

func _on_attack_area_body_entered(body: Node2D) -> void:
	if is_dying or is_paused:
		return
	
	# Check for both "heroes" and "heros" groups (there's a typo in some code)
	if (body.is_in_group("heroes") or body.is_in_group("heros")) and target_hero == null:
		print("Enemy: Hero entered attack range: " + body.name)
		target_hero = body
		speed = 0
		if animation:
			animation.play("attack1")
		if attack_hero_timer and attack_hero_timer.is_stopped():
			attack_hero_timer.start()
			# Immediately deal first damage
			if target_hero and target_hero.has_method("take_damage") and not is_paused:
				print("Enemy: Initial attack on hero for " + str(attack_damage) + " damage")
				target_hero.take_damage(attack_damage)
	elif body.is_in_group("base"):
		speed = 0
		if animation:
			animation.play("attack1")
		if attack_base_timer and attack_base_timer.is_stopped():
			attack_base_timer.start()

func _on_attack_area_body_exited(body: Node2D) -> void:
	if is_dying or is_paused:
		return
	
	if body == target_hero:
		target_hero = null
		speed = local_original_speed  # Use local variable
		if attack_hero_timer:
			attack_hero_timer.stop()
		if animation:
			animation.play("run")
	elif body.is_in_group("base"):
		# Reset base attack if enemy leaves the collision (it can still re-detect later)
		speed = local_original_speed  # Use local variable
		if attack_base_timer:
			attack_base_timer.stop()
		if animation:
			animation.play("run")

# Override the set_paused method from the parent class to handle specific behavior
func set_paused(paused: bool):
	is_paused = paused
	
	# Store velocity when pausing, restore when unpausing
	if is_paused:
		stored_velocity = velocity
		velocity = Vector2.ZERO
		
		# Pause timers
		if path_update_timer:
			path_update_timer.paused = true
		if slow_timer:
			slow_timer.paused = true
		if attack_hero_timer:
			attack_hero_timer.paused = true
		if attack_base_timer:
			attack_base_timer.paused = true
		
		# Pause animations
		if animation:
			animation.pause()
		
		# Find and pause all animation players in children
		for child in get_children():
			if child is AnimationPlayer:
				child.pause()
			elif child is AnimatedSprite2D:
				child.pause()
	else:
		# Resume movement
		velocity = stored_velocity
		
		# Resume timers
		if path_update_timer:
			path_update_timer.paused = false
		if slow_timer:
			slow_timer.paused = false
		if attack_hero_timer:
			attack_hero_timer.paused = false
		if attack_base_timer:
			attack_base_timer.paused = false
		
		# Resume animations
		if animation:
			animation.play()
		
		# Find and resume all animation players in children
		for child in get_children():
			if child is AnimationPlayer:
				child.play()
			elif child is AnimatedSprite2D:
				child.play()
	
	print("Enemy: Pause state set to " + str(paused))
