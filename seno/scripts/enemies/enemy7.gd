extends "res://scripts/enemies/enemy_base.gd"

# Projectile properties
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 250.0
@export var projectile_damage: float = 15.0
@export var projectile_spawn_offset: Vector2 = Vector2(0, -20)
@export var attack_cooldown_time: float = 2.0

# Enemy specific properties
@export var speed: float = 50.0  # Local speed variable
var local_original_speed: float = 0.0  # Store original speed locally

# Node references
@onready var projectile_spawn_point = $Visuals/ProjectileSpawnPoint
@onready var animation = $Visuals/AnimatedSprite2D
@onready var projectile_timer = Timer.new()
@onready var attack_cooldown_timer = Timer.new()
@onready var attack_base_timer = $AttackBase
@onready var attack_area = $AttackArea

# State variables
var target_hero: Node2D = null
var target_base: Node2D = null
var can_shoot: bool = true
var hero_detection_range: float = 250.0
var base_attack_range: float = 200.0
var is_attacking_base: bool = false
var is_attacking_hero: bool = false
var base_in_range: bool = false

func _ready():
	# Find the base
	target_base = get_tree().get_first_node_in_group("base")
	target = target_base  # Set the base class target
	
	# Store the original speed locally
	local_original_speed = speed
	
	# Set base enemy properties
	move_speed = speed  # Set the parent class move_speed from our local speed
	health = 500.0
	max_health = 500.0  # Set max_health for enemy_x
	damage = projectile_damage
	attack_range = hero_detection_range
	gold_value = 100  # Worth more gold when killed
	
	# Initialize animation
	if animation:
		animation.play("run")
	
	# Create and configure projectile timer
	projectile_timer.one_shot = true
	projectile_timer.wait_time = 0.3  # Delay before spawning projectile (adjust to match animation)
	projectile_timer.timeout.connect(_on_projectile_timer_timeout)
	add_child(projectile_timer)
	print("EnemyX: Created projectile timer with delay: " + str(projectile_timer.wait_time) + "s")
	
	# Create and configure attack cooldown timer
	attack_cooldown_timer.one_shot = true
	attack_cooldown_timer.wait_time = attack_cooldown_time
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timeout)
	add_child(attack_cooldown_timer)
	print("EnemyX: Created attack cooldown timer with delay: " + str(attack_cooldown_timer.wait_time) + "s")
	
	# Set up base attack timer if it doesn't exist
	if not attack_base_timer:
		attack_base_timer = Timer.new()
		attack_base_timer.name = "AttackBase"
		add_child(attack_base_timer)
	
	attack_base_timer.wait_time = attack_cooldown_time
	attack_base_timer.one_shot = false
	attack_base_timer.timeout.connect(_on_attack_base_timeout)
	
	# Connect attack area signals
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)
		print("EnemyX: Connected attack area signals")
	else:
		print("EnemyX: WARNING - attack_area node not found, hero detection will not work properly")
	
	# Load the projectile scene if not assigned in the inspector
	if not projectile_scene:
		var scene_path = "res://scenes/projectiles/enemy_projectile.tscn"
		if ResourceLoader.exists(scene_path):
			projectile_scene = load(scene_path)
			print("EnemyX: Loaded projectile scene from: " + scene_path)
		else:
			print("EnemyX: WARNING - Could not find projectile scene at: " + scene_path)
	
	# Call parent _ready function
	super._ready()
	
	# Make sure health bar is properly initialized with our max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	else:
		# Create health bar if it doesn't exist
		create_health_bar()
	
	print("EnemyX: Initialized with speed: " + str(speed) + ", attack range: " + str(attack_range) + ", damage: " + str(damage))
	print("EnemyX: Ready with health: " + str(health) + "/" + str(max_health))

# Create a health bar for the enemy
func create_health_bar():
	# Create a ProgressBar node for the health bar
	var new_health_bar = ProgressBar.new()
	new_health_bar.name = "HealthBar"
	
	# Set size and position - make it larger for enemy_x
	new_health_bar.custom_minimum_size = Vector2(40, 6)
	new_health_bar.position = Vector2(-20, -35)  # Position above the enemy
	
	# Set up the health bar properties
	new_health_bar.max_value = max_health
	new_health_bar.value = health
	new_health_bar.show_percentage = false
	
	# Style the health bar - use a different color for enemy_x
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.8, 0.2, 0.8)  # Purple for special enemy
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
	
	print("EnemyX: Created health bar")

# Override take_damage to update the health bar
func take_damage(amount: float):
	if is_dying or is_paused:
		return
	
	health -= amount

	# Update health bar
	if health_bar:
		health_bar.value = health
		
		# Update health bar color based on health percentage
		var health_percent = health / max_health
		var style_box = health_bar.get_theme_stylebox("fill", "")
		
		if style_box is StyleBoxFlat:
			if health_percent > 0.6:
				style_box.bg_color = Color(0.8, 0.2, 0.8)  # Purple for healthy
			elif health_percent > 0.3:
				style_box.bg_color = Color(0.9, 0.4, 0.7)  # Pink for medium health
			else:
				style_box.bg_color = Color(1.0, 0.3, 0.3)  # Red for low health
	
	# Visual feedback for taking damage
	flash_damage()

	if health <= 0:
		die()
	else:
		# Play hit animation if available
		if animation and animation.sprite_frames and animation.sprite_frames.has_animation("hit"):
			animation.play("hit")
			await animation.animation_finished
			
			# Return to previous animation
			if is_attacking_hero or is_attacking_base:
				animation.play("attack1")
			else:
				animation.play("run")

# This is called when a body enters the attack area (close range detection)
func _on_attack_area_body_entered(body):
	if is_dying or is_paused:
		return
	
	# Check if the body is a hero
	if (body.is_in_group("heroes") or body.is_in_group("heros")) and not is_attacking_hero:
		print("EnemyX: Hero entered attack area: " + body.name)
		target_hero = body
		is_attacking_hero = true
		
		# Stop base attack if we were attacking it
		if is_attacking_base:
			stop_base_attack()
		
		# Stop movement immediately
		velocity = Vector2.ZERO
		move_speed = 0
		speed = 0
		
		# Play attack animation if available
		if animation and animation.sprite_frames and animation.sprite_frames.has_animation("attack1"):
			animation.play("attack1")
		
		# Start attack if we can
		if can_shoot:
			start_attack()
	elif body.is_in_group("base") and not is_attacking_hero and not is_attacking_base:
		print("EnemyX: Base entered attack area")
		base_in_range = true
		
		# Start base attack
		start_base_attack()

# This is called when a body exits the attack area
func _on_attack_area_body_exited(body):
	if body == target_hero:
		print("EnemyX: Hero left attack area")
		target_hero = null
		is_attacking_hero = false
		speed = local_original_speed  # Restore original speed
		move_speed = speed  # Update parent class move_speed
		
		# Return to movement animation
		if animation and animation.sprite_frames and animation.sprite_frames.has_animation("run"):
			animation.play("run")
		
		# Check if base is in range to attack
		if base_in_range and target_base and is_instance_valid(target_base):
			start_base_attack()
	elif body.is_in_group("base"):
		print("EnemyX: Base left attack area")
		base_in_range = false
		stop_base_attack()
		speed = local_original_speed  # Restore original speed
		move_speed = speed  # Update parent class move_speed
		
		# Return to movement animation
		if animation and animation.sprite_frames and animation.sprite_frames.has_animation("run"):
			animation.play("run")

func start_attack():
	if is_dying or is_paused or not can_shoot:
		return
	
	print("EnemyX: Starting attack on hero")
	can_shoot = false
	
	# Ensure we're stopped
	velocity = Vector2.ZERO
	move_speed = 0
	speed = 0
	
	# Play attack animation if available
	if animation and animation.sprite_frames and animation.sprite_frames.has_animation("attack1"):
		animation.play("attack1")
	
	# Start timer to spawn projectile
	projectile_timer.start()

func _on_projectile_timer_timeout():
	print("EnemyX: Projectile timer timeout, spawning projectile")
	
	if target_hero and is_instance_valid(target_hero) and is_attacking_hero:
		_spawn_projectile(target_hero)
	elif target_base and is_instance_valid(target_base) and is_attacking_base:
		_spawn_projectile(target_base)
	
	# Start cooldown timer
	attack_cooldown_timer.start()

func _on_attack_cooldown_timeout():
	can_shoot = true
	print("EnemyX: Attack cooldown finished, can shoot again")
	
	# If we still have a target, attack again
	if target_hero and is_instance_valid(target_hero) and is_attacking_hero:
		start_attack()
	elif target_base and is_instance_valid(target_base) and is_attacking_base:
		_spawn_projectile(target_base)
		can_shoot = false
		attack_cooldown_timer.start()

func start_base_attack():
	if is_dying or is_paused or is_attacking_hero:
		return
	
	print("EnemyX: Starting attack on base")
	is_attacking_base = true
	
	# Ensure we're stopped
	velocity = Vector2.ZERO
	move_speed = 0
	speed = 0
	
	# Play attack animation if available
	if animation and animation.sprite_frames and animation.sprite_frames.has_animation("attack1"):
		animation.play("attack1")
	
	# Start base attack timer if it's not already running
	if attack_base_timer.is_stopped():
		attack_base_timer.start()
		
		# Immediately fire first projectile
		if can_shoot:
			_spawn_projectile(target_base)
			can_shoot = false
			attack_cooldown_timer.start()

func stop_base_attack():
	is_attacking_base = false
	
	# Stop the base attack timer
	if attack_base_timer and not attack_base_timer.is_stopped():
		attack_base_timer.stop()
	
	# Restore speed
	speed = local_original_speed
	move_speed = speed
	
	print("EnemyX: Stopped base attack")

func _on_attack_base_timeout():
	if is_dying or is_paused:
		return
	
	if target_base and is_instance_valid(target_base) and is_attacking_base:
		print("EnemyX: Base attack timer timeout")
		
		# If we can shoot, spawn a projectile at the base
		if can_shoot:
			_spawn_projectile(target_base)
			can_shoot = false
			attack_cooldown_timer.start()
	else:
		# Stop the timer if the base is no longer valid
		stop_base_attack()

func _spawn_projectile(target_node: Node2D):
	if not target_node or not is_instance_valid(target_node) or is_dying or is_paused:
		print("EnemyX: Cannot spawn projectile - invalid target or enemy state")
		return
	
	# Check if target is a hero and is dying
	if target_node == target_hero and target_hero.has_method("is_dying") and target_hero.is_dying:
		print("EnemyX: Target hero is dying, canceling projectile")
		target_hero = null
		is_attacking_hero = false
		return
	
	# Check if we have a projectile scene
	if not projectile_scene:
		print("EnemyX: ERROR - No projectile scene assigned!")
		
		# Try to load the scene one more time
		var scene_path = "res://scenes/projectiles/enemy_projectile.tscn"
		if ResourceLoader.exists(scene_path):
			projectile_scene = load(scene_path)
			print("EnemyX: Loaded projectile scene from: " + scene_path)
		else:
			# Create a simple projectile on the fly if we can't load the scene
			print("EnemyX: Creating a simple projectile as fallback")
			_create_simple_projectile(target_node)
			return
	
	print("EnemyX: Spawning projectile targeting " + target_node.name)
	
	# Create projectile instance
	var projectile = projectile_scene.instantiate()
	
	# Determine spawn position
	var spawn_position = global_position
	if projectile_spawn_point and is_instance_valid(projectile_spawn_point):
		spawn_position = projectile_spawn_point.global_position
		print("EnemyX: Using ProjectileSpawnPoint at " + str(spawn_position))
	else:
		# If no spawn point, use a position slightly in front of the enemy based on facing direction
		var offset = projectile_spawn_offset
		if animation and animation.flip_h:
			offset.x = -offset.x  # Flip offset if facing left
		spawn_position = global_position + offset
		print("EnemyX: Using calculated spawn position at " + str(spawn_position))
	
	# Set projectile properties
	projectile.global_position = spawn_position
	projectile.target = target_node
	
	# Set projectile-specific properties if they exist
	if projectile.has_method("set_damage"):
		projectile.set_damage(projectile_damage)
	elif "damage" in projectile:
		projectile.damage = projectile_damage
	
	if projectile.has_method("set_speed"):
		projectile.set_speed(projectile_speed)
	elif "speed" in projectile:
		projectile.speed = projectile_speed
	
	# Add to scene
	get_parent().add_child(projectile)
	print("EnemyX: Successfully spawned projectile")

# Create a simple projectile as a fallback if the scene can't be loaded
func _create_simple_projectile(target_node: Node2D):
	# Create a new Area2D node
	var projectile = Area2D.new()
	projectile.name = "SimpleEnemyProjectile"
	
	# Add a script to the projectile
	var script = GDScript.new()
	script.source_code = """
extends Area2D

var target: Node2D = null
var speed: float = 250.0
var damage: float = 15.0
var has_hit: bool = false

func _ready():
	# Create a collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8.0
	collision.shape = shape
	add_child(collision)
	
	# Create a visual representation
	var sprite = ColorRect.new()
	sprite.color = Color(0.8, 0.2, 0.2, 0.8)  # Red color for enemy projectile
	sprite.size = Vector2(16, 16)
	sprite.position = Vector2(-8, -8)
	add_child(sprite)
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	
	# Set up auto-destruction timer
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(queue_free)
	add_child(timer)

func _process(delta):
	if has_hit:
		return
	
	if target and is_instance_valid(target):
		# Home in on target
		var direction = global_position.direction_to(target.global_position)
		var velocity = direction * speed
		
		# Move projectile
		global_position += velocity * delta
		
		# Rotate to face direction of movement
		rotation = velocity.angle()
	else:
		# Target is no longer valid, destroy projectile
		queue_free()

func _on_body_entered(body):
	if has_hit:
		return
	
	if body.is_in_group("heroes") or body.is_in_group("heros"):
		has_hit = true
		
		# Deal damage
		if body.has_method("take_damage"):
			body.take_damage(damage)
		
		# Fade out and destroy
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
		tween.tween_callback(queue_free)
	elif body.is_in_group("base"):
		has_hit = true
		
		# Deal damage to base
		if body.has_method("take_damage_base"):
			body.take_damage_base(damage)
			print("SimpleEnemyProjectile: Hit base and dealt " + str(damage) + " damage")
		
		# Fade out and destroy
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
		tween.tween_callback(queue_free)
	
	# Destroy on hitting barriers or other solid objects
	elif body.is_in_group("barriers") or body.is_in_group("solid"):
		has_hit = true
		
		# Fade out and destroy
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
		tween.tween_callback(queue_free)
"""
	script.reload()
	projectile.set_script(script)
	
	# Set projectile properties
	var spawn_position = global_position
	if projectile_spawn_point and is_instance_valid(projectile_spawn_point):
		spawn_position = projectile_spawn_point.global_position
	else:
		var offset = projectile_spawn_offset
		if animation and animation.flip_h:
			offset.x = -offset.x
		spawn_position = global_position + offset
	
	projectile.global_position = spawn_position
	projectile.target = target_node
	
	# Add to scene
	get_parent().add_child(projectile)
	print("EnemyX: Created simple fallback projectile")

# Override die method to clean up timers
func die():
	if is_dying:
		return
	
	# Stop timers
	if projectile_timer:
		projectile_timer.stop()
	if attack_cooldown_timer:
		attack_cooldown_timer.stop()
	if attack_base_timer:
		attack_base_timer.stop()
	
	# Call parent die method
	super.die()

# Override set_paused to handle additional timers
func set_paused(paused: bool):
	# Call parent method first
	super.set_paused(paused)
	
	# Handle additional timers
	if projectile_timer:
		projectile_timer.paused = paused
	if attack_cooldown_timer:
		attack_cooldown_timer.paused = paused
	if attack_base_timer:
		attack_base_timer.paused = paused

# Override apply_slow to handle local speed variable
func apply_slow(amount: float, duration: float):
	# Call parent method first
	super.apply_slow(amount, duration)
	
	# Also update local speed variable
	if not is_slowed:
		local_original_speed = speed
	
	# Apply slow effect to local speed
	speed = local_original_speed * (1.0 - amount)
	move_speed = speed  # Update parent class move_speed
	print("EnemyX: Applied slow effect. Speed reduced from " + str(local_original_speed) + " to " + str(speed))

# Override _on_slow_timer_timeout to restore local speed
func _on_slow_timer_timeout():
	# Call parent method first
	super._on_slow_timer_timeout()
	
	# Restore local speed
	speed = local_original_speed
	move_speed = speed  # Update parent class move_speed
	print("EnemyX: Slow effect expired. Speed restored to " + str(speed))

# Override _update_facing from parent class if it exists
func _update_facing():
	if animation:
		if velocity.x < 0:
			animation.flip_h = true
		elif velocity.x > 0:
			animation.flip_h = false
