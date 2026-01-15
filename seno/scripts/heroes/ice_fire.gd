extends Area2D

var target: Node2D = null
var speed: float = 250.0
var damage: float = 15.0
var slow_amount: float = 0.5
var slow_duration: float = 4.0
var has_hit: bool = false
var angle_offset: float = 0.0  # For multi-shot spread

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

	print("IceProjectile: Ready")

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
		print("IceProjectile: Hit enemy " + body.name)
		has_hit = true
		
		# Deal damage
		if body.has_method("take_damage"):
			body.take_damage(damage)
		
		# Apply slow effect if the enemy supports it
		if body.has_method("apply_slow"):
			body.apply_slow(slow_amount, slow_duration)
			print("IceProjectile: Applied slow effect: " + str(slow_amount * 100) + "% for " + str(slow_duration) + " seconds")
		else:
			print("IceProjectile: Enemy doesn't have apply_slow method")
		
		# Fade out and destroy
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
		tween.tween_callback(queue_free)

	# Destroy on hitting barriers or other solid objects
	elif body.is_in_group("barriers") or body.is_in_group("solid"):
		print("IceProjectile: Hit barrier or solid object")
		has_hit = true
		
		# Fade out and destroy
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
		tween.tween_callback(queue_free)

func _on_timer_timeout():
	# Safety cleanup if projectile hasn't hit anything after a while
	if not has_hit:
		print("IceProjectile: Timeout - destroying")
		queue_free()

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
