extends "res://scripts/heroes/heros_base.gd"

# Ice Wizard specific properties
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 250.0
@export var slow_effect_amount: float = 0.5  # 50% slow
@export var slow_effect_duration: float = 4.0
@export var projectile_spawn_offset: Vector2 = Vector2(0, -20)
@export var multi_shot: bool = false  # Can shoot multiple projectiles at once
@export var multi_shot_count: int = 3  # Number of projectiles in multi-shot

# Node references specific to ice wizard
@onready var projectile_spawn_point = $Visuals/ProjectileSpawnPoint
@onready var animated_sprite = $Visuals/AnimatedSprite2D
@onready var projectile_timer = Timer.new()

func _ready():
	# Set base hero properties through assignment
	hero_type = "ice_wizard"
	max_health = 70.0
	health = max_health
	attack_range = 180.0
	attack_speed = 0.8  # Slower attack speed than fire wizard
	damage = 75.0  # Less damage than fire wizard
	base_cost = 250  # More expensive than fire wizard

	# Create and configure projectile timer
	projectile_timer.one_shot = true
	projectile_timer.wait_time = 0.3  # Delay before spawning projectile (adjust to match animation)
	projectile_timer.timeout.connect(_on_projectile_timer_timeout)
	add_child(projectile_timer)
	print("IceWizard: Created projectile timer with delay: " + str(projectile_timer.wait_time) + "s")

	# Load the projectile scene if not assigned in the inspector
	if not projectile_scene:
		var scene_path = "res://scenes/projectiles/ice_projectile.tscn"
		if ResourceLoader.exists(scene_path):
			projectile_scene = load(scene_path)
			print("IceWizard: Loaded projectile scene from: " + scene_path)
		else:
			print("IceWizard: WARNING - Could not find projectile scene at: " + scene_path)
			# Try alternative paths
			var alt_paths = [
				"res://ice_projectile.tscn",
				"res://scenes/ice_projectile.tscn",
				"res://projectiles/ice_projectile.tscn"
			]
			
			for path in alt_paths:
				if ResourceLoader.exists(path):
					projectile_scene = load(path)
					print("IceWizard: Loaded projectile scene from alternative path: " + path)
					break

	# Call parent _ready function
	super._ready()

	print("IceWizard: Initialized with attack speed: " + str(attack_speed) + ", damage: " + str(damage))
	print("IceWizard: Projectile scene assigned: " + str(projectile_scene != null))

# Override perform_attack to implement ice wizard specific attack
func perform_attack():
	if not target_enemy or not is_instance_valid(target_enemy):
		return

	# Skip enemies that are dying
	if target_enemy.has_method("is_dying") and target_enemy.is_dying:
		target_enemy = null
		stop_attack()
		return

	print("IceWizard: Performing ice attack")

	# Play attack sound
	if audio_player and attack_sound:
		audio_player.stream = attack_sound
		audio_player.play()

	# Play attack animation
	if animated_sprite:
		animated_sprite.play("attack1")
	
	# Start timer to spawn projectile
	projectile_timer.start()
	
	# Emit signal
	emit_signal("attack_performed", target_enemy)

# Called when the projectile timer times out
func _on_projectile_timer_timeout():
	print("IceWizard: Projectile timer timeout, spawning projectile")
	_spawn_ice_projectile()

# Spawn ice projectile
func _spawn_ice_projectile():
	if not target_enemy or not is_instance_valid(target_enemy) or is_moving:
		print("IceWizard: Cannot spawn projectile - invalid target or moving")
		return

	# Skip enemies that are dying
	if target_enemy.has_method("is_dying") and target_enemy.is_dying:
		print("IceWizard: Target is dying, canceling projectile")
		target_enemy = null
		stop_attack()
		return

	# Check if we have a projectile scene
	if not projectile_scene:
		print("IceWizard: ERROR - No projectile scene assigned!")
		
		# Try to load the scene one more time
		var scene_path = "res://scenes/projectiles/ice_projectile.tscn"
		if ResourceLoader.exists(scene_path):
			projectile_scene = load(scene_path)
			print("IceWizard: Loaded projectile scene from: " + scene_path)
		else:
			# Create a simple projectile on the fly if we can't load the scene
			print("IceWizard: Creating a simple projectile as fallback")
			_create_simple_projectile()
			return

	print("IceWizard: Spawning ice projectile")

	if multi_shot:
		# Spawn multiple projectiles in a spread pattern
		_spawn_multi_shot()
	else:
		# Spawn a single projectile
		_spawn_single_projectile()

# Spawn a single ice projectile
func _spawn_single_projectile():
	# Create projectile instance
	var projectile = projectile_scene.instantiate()

	# Determine spawn position
	var spawn_position = _get_spawn_position()

	# Set projectile properties
	projectile.global_position = spawn_position
	projectile.target = target_enemy

	# Set projectile-specific properties if they exist
	if projectile.has_method("set_damage"):
		projectile.set_damage(damage)
	elif "damage" in projectile:
		projectile.damage = damage

	if projectile.has_method("set_speed"):
		projectile.set_speed(projectile_speed)
	elif "speed" in projectile:
		projectile.speed = projectile_speed

	if projectile.has_method("set_slow_effect"):
		projectile.set_slow_effect(slow_effect_amount, slow_effect_duration)
	elif "slow_amount" in projectile:
		projectile.slow_amount = slow_effect_amount
		projectile.slow_duration = slow_effect_duration

	# Add to scene
	get_parent().add_child(projectile)
	print("IceWizard: Successfully spawned ice projectile")

# Spawn multiple ice projectiles in a spread pattern
func _spawn_multi_shot():
	var spread_angle = 30.0  # Total spread angle in degrees
	var angle_step = spread_angle / (multi_shot_count - 1) if multi_shot_count > 1 else 0
	var start_angle = -spread_angle / 2

	for i in range(multi_shot_count):
		# Create projectile instance
		var projectile = projectile_scene.instantiate()
		
		# Determine spawn position
		var spawn_position = _get_spawn_position()
		
		# Set projectile properties
		projectile.global_position = spawn_position
		projectile.target = target_enemy
		
		# Calculate spread angle for this projectile
		var current_angle = start_angle + (angle_step * i)
		
		# Set projectile-specific properties
		if projectile.has_method("set_damage"):
			projectile.set_damage(damage * 0.7)  # Reduce damage for multi-shot
		elif "damage" in projectile:
			projectile.damage = damage * 0.7
		
		if projectile.has_method("set_speed"):
			projectile.set_speed(projectile_speed)
		elif "speed" in projectile:
			projectile.speed = projectile_speed
		
		if projectile.has_method("set_slow_effect"):
			projectile.set_slow_effect(slow_effect_amount, slow_effect_duration)
		elif "slow_amount" in projectile:
			projectile.slow_amount = slow_effect_amount
			projectile.slow_duration = slow_effect_duration
		
		if projectile.has_method("set_angle_offset"):
			projectile.set_angle_offset(deg_to_rad(current_angle))
		elif "angle_offset" in projectile:
			projectile.angle_offset = deg_to_rad(current_angle)
		
		# Add to scene
		get_parent().add_child(projectile)
		print("IceWizard: Spawned multi-shot projectile " + str(i+1) + " of " + str(multi_shot_count))
		
		# Add a small delay between spawning projectiles
		await get_tree().create_timer(0.05).timeout

# Helper function to get spawn position
func _get_spawn_position() -> Vector2:
	var spawn_position = global_position
	if projectile_spawn_point and is_instance_valid(projectile_spawn_point):
		spawn_position = projectile_spawn_point.global_position
		print("IceWizard: Using ProjectileSpawnPoint at " + str(spawn_position))
	else:
		# If no spawn point, use a position slightly in front of the hero based on facing direction
		var offset = projectile_spawn_offset
		if animated_sprite and animated_sprite.flip_h:
			offset.x = -offset.x  # Flip offset if facing left
		spawn_position = global_position + offset
		print("IceWizard: Using calculated spawn position at " + str(spawn_position))

	return spawn_position

# Create a simple projectile as a fallback if the scene can't be loaded
func _create_simple_projectile():
	# Create a new Area2D node
	var projectile = Area2D.new()
	projectile.name = "SimpleIceProjectile"

	# Add a script to the projectile
	var script = GDScript.new()
	script.source_code = """
extends Area2D

var target: Node2D = null
var speed: float = 250.0
var damage: float = 15.0
var slow_amount: float = 0.5
var slow_duration: float = 4.0
var has_hit: bool = false
var angle_offset: float = 0.0

func _ready():
	# Create a collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8.0
	collision.shape = shape
	add_child(collision)

	# Create a visual representation
	var sprite = ColorRect.new()
	sprite.color = Color(0.7, 0.9, 1.0, 0.8)  # Light blue color
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
		# Home in on target with angle offset
		var base_direction = global_position.direction_to(target.global_position)
		var direction = base_direction.rotated(angle_offset)
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

	if body.is_in_group("enemies"):
		has_hit = true
		
		# Deal damage
		if body.has_method("take_damage"):
			body.take_damage(damage)
		
		# Apply slow effect if the enemy supports it
		if body.has_method("apply_slow"):
			body.apply_slow(slow_amount, slow_duration)
		
		# Fade out and destroy
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(0.7, 0.9, 1.0, 0), 0.5)
		tween.tween_callback(queue_free)

# Destroy on hitting barriers or other solid objects
elif body.is_in_group("barriers") or body.is_in_group("solid"):
	has_hit = true
	
	# Fade out and destroy
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.7, 0.9, 1.0, 0), 0.5)
	tween.tween_callback(queue_free)

# Setter methods for external configuration
func set_damage(value: float):
	damage = value

func set_speed(value: float):
	speed = value

func set_slow_effect(amount: float, duration: float):
	slow_amount = amount
	slow_duration = duration

func set_angle_offset(angle: float):
	angle_offset = angle
"""
	script.reload()
	projectile.set_script(script)

	# Set projectile properties
	var spawn_position = _get_spawn_position()
	projectile.global_position = spawn_position
	projectile.target = target_enemy

	# Add to scene
	get_parent().add_child(projectile)
	print("IceWizard: Created simple fallback projectile")

# Override stop_attack to also stop the projectile timer
func stop_attack():
	super.stop_attack()
	projectile_timer.stop()
