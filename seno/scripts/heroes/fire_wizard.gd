extends "res://scripts/heroes/heros_base.gd"

# Fire Wizard specific properties
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 300.0
@export var fire_damage_over_time: float = 5.0
@export var fire_dot_duration: float = 3.0
@export var projectile_spawn_offset: Vector2 = Vector2(0, -20)

# Node references specific to fire wizard
@onready var projectile_spawn_point = $Visuals/ProjectileSpawnPoint
@onready var animated_sprite = $Visuals/AnimatedSprite2D
@onready var projectile_timer = Timer.new()

func _ready():
	# Set base hero properties through assignment
	hero_type = "fire_wizard"
	max_health = 80.0
	health = max_health
	attack_range = 200.0
	attack_speed = 1.2
	damage = 100.0
	base_cost = 200

	# Create and configure projectile timer
	projectile_timer.one_shot = true
	projectile_timer.wait_time = 0.3  # Delay before spawning projectile (adjust to match animation)
	projectile_timer.timeout.connect(_on_projectile_timer_timeout)
	add_child(projectile_timer)
	print("FireWizard: Created projectile timer with delay: " + str(projectile_timer.wait_time) + "s")

	# Load the projectile scene if not assigned in the inspector
	if not projectile_scene:
		var scene_path = "res://scenes/projectiles/fire_projectile.tscn"
		if ResourceLoader.exists(scene_path):
			projectile_scene = load(scene_path)
			print("FireWizard: Loaded projectile scene from: " + scene_path)
		else:
			print("FireWizard: WARNING - Could not find projectile scene at: " + scene_path)
			# Try alternative paths

	# Call parent _ready function
	super._ready()

	print("FireWizard: Initialized with attack speed: " + str(attack_speed) + ", damage: " + str(damage))
	print("FireWizard: Projectile scene assigned: " + str(projectile_scene != null))

# Override perform_attack to implement fire wizard specific attack
func perform_attack():
	if not target_enemy or not is_instance_valid(target_enemy):
		return

	# Skip enemies that are dying
	if target_enemy.has_method("is_dying") and target_enemy.is_dying:
		target_enemy = null
		stop_attack()
		return

	print("FireWizard: Performing fire attack")

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
	print("FireWizard: Projectile timer timeout, spawning projectile")
	_spawn_fire_projectile()

# Spawn fire projectile
func _spawn_fire_projectile():
	if not target_enemy or not is_instance_valid(target_enemy) or is_moving:
		print("FireWizard: Cannot spawn projectile - invalid target or moving")
		return

	# Skip enemies that are dying
	if target_enemy.has_method("is_dying") and target_enemy.is_dying:
		print("FireWizard: Target is dying, canceling projectile")
		target_enemy = null
		stop_attack()
		return

	# Check if we have a projectile scene
	if not projectile_scene:
		print("FireWizard: ERROR - No projectile scene assigned!")
		
		# Try to load the scene one more time
		var scene_path = "res://scenes/projectiles/fire_projectile.tscn"
		if ResourceLoader.exists(scene_path):
			projectile_scene = load(scene_path)
			print("FireWizard: Loaded projectile scene from: " + scene_path)
		else:
			# Create a simple projectile on the fly if we can't load the scene
			print("FireWizard: Creating a simple projectile as fallback")
			_create_simple_projectile()
			return

	print("FireWizard: Spawning fire projectile")

	# Create projectile instance
	var projectile = projectile_scene.instantiate()

	# Determine spawn position
	var spawn_position = global_position
	if projectile_spawn_point and is_instance_valid(projectile_spawn_point):
		spawn_position = projectile_spawn_point.global_position
		print("FireWizard: Using ProjectileSpawnPoint at " + str(spawn_position))
	else:
		# If no spawn point, use a position slightly in front of the hero based on facing direction
		var offset = projectile_spawn_offset
		if animated_sprite and animated_sprite.flip_h:
			offset.x = -offset.x  # Flip offset if facing left
		spawn_position = global_position + offset
		print("FireWizard: Using calculated spawn position at " + str(spawn_position))

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

	if projectile.has_method("set_dot_damage"):
		projectile.set_dot_damage(fire_damage_over_time, fire_dot_duration)
	elif "dot_damage" in projectile:
		projectile.dot_damage = fire_damage_over_time
		projectile.dot_duration = fire_dot_duration

	# Add to scene
	get_parent().add_child(projectile)
	print("FireWizard: Successfully spawned fire projectile")

# Create a simple projectile as a fallback if the scene can't be loaded
func _create_simple_projectile():
	# Create a new Area2D node
	var projectile = Area2D.new()
	projectile.name = "SimpleFireProjectile"

	# Add a script to the projectile
	var script = GDScript.new()
	script.source_code = """
extends Area2D

var target: Node2D = null
var speed: float = 300.0
var damage: float = 20.0
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
	sprite.color = Color(1.0, 0.5, 0.0, 0.8)  # Orange color
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

	if body.is_in_group("enemies"):
		has_hit = true
		
		# Deal damage
		if body.has_method("take_damage"):
			body.take_damage(damage)
		
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
		if animated_sprite and animated_sprite.flip_h:
			offset.x = -offset.x
		spawn_position = global_position + offset

	projectile.global_position = spawn_position
	projectile.target = target_enemy

	# Add to scene
	get_parent().add_child(projectile)
	print("FireWizard: Created simple fallback projectile")

# Override stop_attack to also stop the projectile timer
func stop_attack():
	super.stop_attack()
	projectile_timer.stop()
