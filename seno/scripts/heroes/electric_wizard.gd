extends "res://scripts/heroes/heros_base.gd"

# Electric Wizard specific properties
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 350.0
@export var max_projectile_distance: float = 400.0
@export var pierce_count: int = 5  # Number of enemies each projectile can hit
@export var projectile_spawn_offset: Vector2 = Vector2(0, -20)
@export var chain_lightning: bool = false  # Whether to use chain lightning effect

# Node references specific to electric wizard
@onready var projectile_spawn_point = $Visuals/ProjectileSpawnPoint
@onready var animated_sprite = $Visuals/AnimatedSprite2D
@onready var projectile_timer = Timer.new()

func _ready():
	# Set base hero properties through assignment
	hero_type = "electric_wizard"
	max_health = 65.0  # Less health than other wizards
	health = max_health
	attack_range = 220.0  # Longer range than ice wizard
	attack_speed = 0.7  # Slower attack speed
	damage =130.0  # Medium damage
	base_cost = 300  # More expensive than other wizards

	# Create and configure projectile timer
	projectile_timer.one_shot = true
	projectile_timer.wait_time = 0.3  # Delay before spawning projectile
	projectile_timer.timeout.connect(_on_projectile_timer_timeout)
	add_child(projectile_timer)

	# Load the projectile scene if not assigned in the inspector
	if not projectile_scene:
		var scene_path = "res://scenes/projectiles/electric_projectile.tscn"
		if ResourceLoader.exists(scene_path):
			projectile_scene = load(scene_path)
		else:
			# Try alternative paths
			var alt_paths = [
				"res://electric_projectile.tscn",
				"res://scenes/electric_projectile.tscn",
				"res://projectiles/electric_projectile.tscn"
			]
			
			for path in alt_paths:
				if ResourceLoader.exists(path):
					projectile_scene = load(path)
					break

	# Call parent _ready function
	super._ready()



# Override perform_attack to implement electric wizard specific attack
func perform_attack():
	if not target_enemy or not is_instance_valid(target_enemy):
		return

	# Skip enemies that are dying
	if target_enemy.has_method("is_dying") and target_enemy.is_dying:
		target_enemy = null
		stop_attack()
		return


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
	_spawn_electric_projectile()

# Spawn electric projectile
func _spawn_electric_projectile():
	if not target_enemy or not is_instance_valid(target_enemy) or is_moving:
		return

	# Skip enemies that are dying
	if target_enemy.has_method("is_dying") and target_enemy.is_dying:
		target_enemy = null
		stop_attack()
		return

	# Check if we have a projectile scene
	if not projectile_scene:
		
		# Try to load the scene one more time
		var scene_path = "res://scenes/projectiles/electric_projectile.tscn"
		if ResourceLoader.exists(scene_path):
			projectile_scene = load(scene_path)
		else:
			# Create a simple projectile on the fly if we can't load the scene
			_create_simple_projectile()
			return


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

	if projectile.has_method("set_max_distance"):
		projectile.set_max_distance(max_projectile_distance)
	elif "max_distance" in projectile:
		projectile.max_distance = max_projectile_distance
		
	if projectile.has_method("set_pierce_count"):
		projectile.set_pierce_count(pierce_count)
	elif "pierce_count" in projectile:
		projectile.pierce_count = pierce_count

	# Add to scene
	get_parent().add_child(projectile)

# Helper function to get spawn position
func _get_spawn_position() -> Vector2:
	var spawn_position = global_position
	if projectile_spawn_point and is_instance_valid(projectile_spawn_point):
		spawn_position = projectile_spawn_point.global_position
	else:
		# If no spawn point, use a position slightly in front of the hero based on facing direction
		var offset = projectile_spawn_offset
		if animated_sprite and animated_sprite.flip_h:
			offset.x = -offset.x  # Flip offset if facing left
		spawn_position = global_position + offset

	return spawn_position

# Create a simple projectile as a fallback if the scene can't be loaded
func _create_simple_projectile():
	# Create a new Area2D node
	var projectile = Area2D.new()
	projectile.name = "SimpleElectricProjectile"

	# Add a script to the projectile
	var script = GDScript.new()
	script.source_code = """
extends Area2D

var target: Node2D = null
var speed: float = 350.0
var damage: float = 18.0
var max_distance: float = 400.0
var pierce_count: int = 5
var hit_enemies = []
var start_position: Vector2
var has_expired: bool = false

func _ready():
	# Create a collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8.0
	collision.shape = shape
	add_child(collision)

	# Create a visual representation
	var sprite = ColorRect.new()
	sprite.color = Color(0.5, 0.8, 1.0, 0.8)  # Electric blue color
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
	
	# Store starting position
	start_position = global_position

func _process(delta):
	if has_expired:
		return
		
	# Check if we've exceeded max distance
	var distance_traveled = global_position.distance_to(start_position)
	if distance_traveled >= max_distance:
		expire()
		return

	# Always continue in the current direction, never follow the target
	var direction = Vector2(cos(rotation), sin(rotation))
	
	# If we have a target and haven't started moving yet, set initial direction toward target
	if target and is_instance_valid(target) and distance_traveled < 10:
		direction = global_position.direction_to(target.global_position)
		# Store this direction by updating our rotation
		rotation = direction.angle()
	
	# Move projectile at constant speed
	global_position += direction * speed * delta

func _on_body_entered(body):
	if has_expired:
		return

	if body.is_in_group("enemies"):
		# Skip if we've already hit this enemy
		if body in hit_enemies:
			return
			
		# Add to hit list
		hit_enemies.append(body)
		
		# Deal damage
		if body.has_method("take_damage"):
			body.take_damage(damage)
		
		# Check if we've hit our pierce limit
		if hit_enemies.size() >= pierce_count:
			expire()
	
	# Destroy on hitting barriers or other solid objects
	elif body.is_in_group("barriers") or body.is_in_group("solid"):
		expire()

func expire():
	if has_expired:
		return
		
	has_expired = true
	
	# Fade out and destroy
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.5, 0.8, 1.0, 0), 0.3)
	tween.tween_callback(queue_free)

# Setter methods for external configuration
func set_damage(value: float):
	damage = value

func set_speed(value: float):
	speed = value

func set_max_distance(value: float):
	max_distance = value

func set_pierce_count(value: int):
	pierce_count = value
"""
	script.reload()
	projectile.set_script(script)

	# Set projectile properties
	var spawn_position = _get_spawn_position()
	projectile.global_position = spawn_position
	projectile.target = target_enemy

	# Add to scene
	get_parent().add_child(projectile)

# Override stop_attack to also stop the projectile timer
func stop_attack():
	super.stop_attack()
	projectile_timer.stop()
