extends Area2D

var target: Node2D = null
var speed: float = 300.0
var damage: float = 20.0
var dot_damage: float = 5.0
var dot_duration: float = 3.0
var has_hit: bool = false

@onready var sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var timer = $Timer

func _ready():
	# Connect signals
	body_entered.connect(_on_body_entered)
	
	# Start animation if it exists
	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation("default"):
			sprite.play("default")
		elif sprite.sprite_frames.has_animation("fire"):
			sprite.play("fire")
	
	# Set up timer for auto-destruction (safety measure)
	if timer:
		timer.wait_time = 5.0  # Destroy after 5 seconds if no hit
		timer.one_shot = true
		timer.timeout.connect(_on_timer_timeout)
		timer.start()
	
	print("FireProjectile: Ready")

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
		print("FireProjectile: Hit enemy " + body.name)
		has_hit = true
		
		# Deal damage
		if body.has_method("take_damage"):
			body.take_damage(damage)
		
		# Apply damage over time if the enemy supports it
		if body.has_method("apply_dot"):
			body.apply_dot("fire", dot_damage, dot_duration)
		
		# Fade out and destroy
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
		tween.tween_callback(queue_free)
	
	# Destroy on hitting barriers or other solid objects
	elif body.is_in_group("barriers") or body.is_in_group("solid"):
		print("FireProjectile: Hit barrier or solid object")
		has_hit = true
		
		# Fade out and destroy
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
		tween.tween_callback(queue_free)

func _on_timer_timeout():
	# Safety cleanup if projectile hasn't hit anything after a while
	if not has_hit:
		print("FireProjectile: Timeout - destroying")
		queue_free()

# Setter methods for external configuration
func set_damage(value: float):
	damage = value

func set_speed(value: float):
	speed = value

func set_dot_damage(dmg: float, duration: float):
	dot_damage = dmg
	dot_duration = duration
