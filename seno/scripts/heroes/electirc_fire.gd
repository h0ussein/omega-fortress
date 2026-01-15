extends Area2D

var target: Node2D = null
var speed: float = 350.0
var damage: float = 18.0
var max_distance: float = 400.0  # Maximum travel distance
var pierce_count: int = 999      # Number of enemies it can pierce through (high number for unlimited)
var hit_enemies = []             # Array to track which enemies we've already hit
var start_position: Vector2      # Starting position to track distance traveled
var has_expired: bool = false    # Flag to track if projectile has expired

@onready var sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var timer = $Timer
@onready var particles = $CPUParticles2D

func _ready():
	# Connect signals
	body_entered.connect(_on_body_entered)
	
	# Start animation if it exists
	if sprite and sprite.sprite_frames:
		sprite.play("default")
	
	# Set up timer for auto-destruction (safety measure)
	if timer:
		timer.timeout.connect(_on_timer_timeout)
	
	# Store starting position
	start_position = global_position
	
	print("ElectricProjectile: Ready")

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
			
		print("ElectricProjectile: Hit enemy " + body.name)
		
		# Add to hit list
		hit_enemies.append(body)
		
		# Deal damage
		if body.has_method("take_damage"):
			body.take_damage(damage)
		
		# Create lightning effect to the hit enemy
		_create_lightning_effect(body.global_position)
		
		# Check if we've hit our pierce limit
		if hit_enemies.size() >= pierce_count:
			expire()
		
		# Important: Don't change direction or stop moving!
	
	# Destroy on hitting barriers or other solid objects
	elif body.is_in_group("barriers") or body.is_in_group("solid"):
		print("ElectricProjectile: Hit barrier or solid object")
		expire()

func _on_timer_timeout():
	# Safety cleanup if projectile hasn't hit anything after a while
	if not has_expired:
		print("ElectricProjectile: Timeout - destroying")
		expire()

func expire():
	if has_expired:
		return
		
	has_expired = true
	
	# Create final lightning effect
	_create_lightning_effect(global_position + Vector2(0, 20))
	
	# Fade out and destroy
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(queue_free)

# Create a lightning effect from the projectile to the target position
func _create_lightning_effect(target_pos: Vector2):
	# Create a Line2D for the lightning
	var lightning = Line2D.new()
	lightning.width = 3
	lightning.default_color = Color(0.5, 0.8, 1.0, 0.8)
	
	# Generate lightning points
	var start_pos = global_position
	var distance = start_pos.distance_to(target_pos)
	var direction = start_pos.direction_to(target_pos)
	var segments = 5 + int(distance / 20)
	
	# Add start point
	lightning.add_point(Vector2.ZERO)
	
	# Add zigzag points
	for i in range(1, segments):
		var percent = float(i) / segments
		var point = direction * distance * percent
		var perpendicular = Vector2(-direction.y, direction.x) * (randf() * 10 - 5)
		lightning.add_point(point + perpendicular)
	
	# Add end point
	lightning.add_point(target_pos - global_position)
	
	# Set lightning position
	lightning.global_position = global_position
	
	# Add to scene
	get_parent().add_child(lightning)
	
	# Fade out and remove after a short time
	var tween = create_tween()
	tween.tween_property(lightning, "modulate", Color(0.5, 0.8, 1.0, 0), 0.2)
	tween.tween_callback(lightning.queue_free)

# Setter methods for external configuration
func set_damage(value: float):
	damage = value

func set_speed(value: float):
	speed = value

func set_max_distance(value: float):
	max_distance = value

func set_pierce_count(value: int):
	pierce_count = value
