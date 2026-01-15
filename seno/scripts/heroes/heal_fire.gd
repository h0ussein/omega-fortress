extends Node2D

var target: Node2D = null
var heal_amount: float = 15.0
var speed: float = 300.0
var max_lifetime: float = 3.0  # Maximum lifetime in seconds
var lifetime: float = 0.0

@onready var sprite = $Sprite2D

func _ready():
	# Set up the visual appearance
	modulate = Color(0.0, 1.0, 0.5)  # Green color for healing
	
	print("HealProjectile: Created with heal amount " + str(heal_amount))

func _process(delta):
	lifetime += delta
	
	# Destroy if lifetime exceeded
	if lifetime > max_lifetime:
		queue_free()
		return
	
	# If target is gone or freed, destroy self
	if not is_instance_valid(target):
		print("HealProjectile: Target is no longer valid, self-destructing")
		queue_free()
		return
	
	# Move towards target
	var direction = global_position.direction_to(target.global_position)
	global_position += direction * speed * delta
	
	# Rotate to face direction of travel
	rotation = direction.angle()
	
	# Check if we've reached the target
	if global_position.distance_to(target.global_position) < 10:
		apply_healing()
		queue_free()

func apply_healing():
	if not is_instance_valid(target):
		print("HealProjectile: Target is no longer valid when trying to heal")
		return
		
	# Try both healing methods for compatibility
	if target.has_method("heal"):
		target.heal(heal_amount)
		print("HealProjectile: Healed " + str(heal_amount) + " health to " + target.name + " using heal()")
	elif target.has_method("take_damage"):
		# Negative damage = healing
		target.take_damage(-heal_amount)
		print("HealProjectile: Healed " + str(heal_amount) + " health to " + target.name + " using take_damage(-)")
	else:
		print("HealProjectile: ERROR - Target has no heal or take_damage method!")
	
	# Create a healing effect
	create_heal_effect()

func create_heal_effect():
	if not is_instance_valid(target):
		print("HealProjectile: Target is no longer valid when creating heal effect")
		return
		
	# Create a visual effect at the target's position
	var effect = CPUParticles2D.new()
	effect.emitting = true
	effect.one_shot = true
	effect.explosiveness = 0.8
	effect.amount = 16
	effect.lifetime = 0.5
	effect.texture = sprite.texture if sprite else null
	effect.direction = Vector2(0, -1)
	effect.spread = 180
	effect.initial_velocity_min = 50
	effect.initial_velocity_max = 100
	effect.modulate = Color(0.0, 1.0, 0.5)  # Green color for healing
	
	# Add to the scene at target's position
	get_parent().add_child(effect)
	effect.global_position = target.global_position
	
	# Set up auto-removal after effect completes
	var timer = get_tree().create_timer(effect.lifetime * 1.5)
	timer.timeout.connect(func(): effect.queue_free())

# This function is not used but kept for compatibility
func _on_area_2d_body_entered(body: Node2D) -> void:
	pass
