extends Area2D

var target: Node2D = null
var speed: float = 250.0
var damage: float = 15.0
var has_hit: bool = false

@onready var sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var timer = $Timer

func _ready():
	# Set up collision layers and masks
	collision_layer = 8  # Layer 4 for projectiles
	collision_mask = 5   # Mask for heroes (layer 3) and base (layer 1)
	
	# Connect signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Start animation if it exists
	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation("default"):
			sprite.play("default")
		elif sprite.sprite_frames.has_animation("dark"):
			sprite.play("dark")
	
	# Set up timer for auto-destruction (safety measure)
	if timer:
		timer.wait_time = 5.0  # Destroy after 5 seconds if no hit
		timer.one_shot = true
		timer.timeout.connect(_on_timer_timeout)
		timer.start()
	
	print("EnemyProjectile: Ready with collision layer " + str(collision_layer) + " and mask " + str(collision_mask))

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

func _physics_process(delta):
	# Manual collision detection as a backup
	if has_hit:
		return
		
	# Check for heroes in the scene
	var heroes = get_tree().get_nodes_in_group("heroes")
	for hero in heroes:
		if hero and is_instance_valid(hero) and not has_hit:
			var distance = global_position.distance_to(hero.global_position)
			if distance < 20:  # Approximate collision radius
				print("EnemyProjectile: Manual collision with hero " + hero.name)
				_on_hit_hero(hero)
				return
	
	# Check for base in the scene
	var bases = get_tree().get_nodes_in_group("base")
	for base in bases:
		if base and is_instance_valid(base) and not has_hit:
			var distance = global_position.distance_to(base.global_position)
			if distance < 30:  # Base is usually larger
				print("EnemyProjectile: Manual collision with base")
				_on_hit_base(base)
				return

func _on_body_entered(body):
	if has_hit:
		return
	
	print("EnemyProjectile: Body entered: " + body.name + " in groups: " + str(body.get_groups()))
	
	if body.is_in_group("heroes") or body.is_in_group("heros"):
		_on_hit_hero(body)
	elif body.is_in_group("base"):
		_on_hit_base(body)
	# Destroy on hitting barriers or other solid objects
	elif body.is_in_group("barriers") or body.is_in_group("solid"):
		print("EnemyProjectile: Hit barrier or solid object")
		has_hit = true
		_play_hit_effect()
		queue_free()

func _on_hit_hero(hero):
	print("EnemyProjectile: Hit hero " + hero.name)
	has_hit = true
	
	# Deal damage - try multiple methods to ensure compatibility
	if hero.has_method("take_damage"):
		print("EnemyProjectile: Calling take_damage on hero with " + str(damage) + " damage")
		hero.take_damage(damage)
	elif hero.has_method("take_damage_hero"):
		print("EnemyProjectile: Calling take_damage_hero on hero with " + str(damage) + " damage")
		hero.take_damage_hero(damage)
	else:
		print("EnemyProjectile: ERROR - Hero has no damage method!")
		# Direct property modification as last resort
		if "health" in hero:
			print("EnemyProjectile: Directly modifying hero health property")
			hero.health -= damage
	
	# Play hit effect
	_play_hit_effect()
	
	# Destroy projectile
	queue_free()

func _on_hit_base(base):
	print("EnemyProjectile: Hit base")
	has_hit = true
	
	# Deal damage to base - try multiple methods
	if base.has_method("take_damage_base"):
		print("EnemyProjectile: Calling take_damage_base on base with " + str(damage) + " damage")
		base.take_damage_base(damage)
	elif base.has_method("take_damage"):
		print("EnemyProjectile: Calling take_damage on base with " + str(damage) + " damage")
		base.take_damage(damage)
	else:
		print("EnemyProjectile: ERROR - Base has no damage method!")
		# Direct property modification as last resort
		if "health" in base:
			print("EnemyProjectile: Directly modifying base health property")
			base.health -= damage
	
	# Play hit effect
	_play_hit_effect()
	
	# Destroy projectile
	queue_free()

func _on_timer_timeout():
	# Safety cleanup if projectile hasn't hit anything after a while
	if not has_hit:
		print("EnemyProjectile: Timeout - destroying")
		queue_free()

func _play_hit_effect():
	# Create a simple hit effect
	modulate = Color(1, 1, 1, 0.7)
	
	# Scale effect
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)

# Setter methods for external configuration
func set_damage(value: float):
	damage = value
	print("EnemyProjectile: Damage set to " + str(damage))

func set_speed(value: float):
	speed = value
