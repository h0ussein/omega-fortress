extends Node2D

@export var max_length: float = 100.0
@export var damage_per_second: float = 30.0
@export var beam_width: float = 4.0
@export var beam_color: Color = Color(1.0, 0.2, 0.2, 0.8)

var target: Node2D = null
var is_active: bool = false
var enemies_hit: Array = []
var is_paused: bool = false  # Add pause state variable

@onready var animated_sprite = $AnimatedSprite2D
@onready var hit_effect = $HitEffect
@onready var damage_timer = $DamageTimer
@onready var collision_area = $CollisionArea
@onready var collision_shape = $CollisionArea/CollisionShape2D

func _ready():
	print("LaserBeam: _ready() called")
	
	# Set up damage timer
	damage_timer.wait_time = 0.1
	damage_timer.timeout.connect(_on_damage_timer_timeout)

	# Connect collision signals
	if collision_area:
		collision_area.body_entered.connect(_on_body_entered)
		collision_area.body_exited.connect(_on_body_exited)
	else:
		print("LaserBeam: ERROR - CollisionArea not found")

	# Hide beam initially
	if animated_sprite:
		animated_sprite.visible = false
		print("LaserBeam: AnimatedSprite2D found and set to invisible initially")
	else:
		print("LaserBeam: ERROR - AnimatedSprite2D not found")

	# Set beam properties
	if animated_sprite:
		# Set beam color
		animated_sprite.modulate = beam_color
		
		# Set beam scale for length and width
		animated_sprite.scale.x = max_length / 100.0  # Assuming original sprite is 100px long
		animated_sprite.scale.y = beam_width
		
		print("LaserBeam: Set beam properties - color: " + str(beam_color) + ", length: " + str(max_length) + ", width: " + str(beam_width))

	# Set collision shape size
	if collision_shape:
		var rect_shape = RectangleShape2D.new()
		rect_shape.extents = Vector2(max_length / 2, beam_width * 2)
		collision_shape.shape = rect_shape
		collision_shape.position.x = max_length / 2  # Center the shape on the beam
		print("LaserBeam: Set collision shape size")
	else:
		print("LaserBeam: ERROR - CollisionShape2D not found")

	print("LaserBeam: Ready with damage_per_second: " + str(damage_per_second))

func _process(delta):
	# Skip processing if paused
	if is_paused:
		return
		
	if not is_active:
		return

	# Update beam direction to point at target
	if target and is_instance_valid(target):
		var target_pos = target.global_position
		var direction = global_position.direction_to(target_pos)
		rotation = direction.angle()
		
		# Debug: Check if beam is visible
		if Engine.get_frames_drawn() % 60 == 0:  # Check once per second
			if animated_sprite:
				print("LaserBeam: Beam visibility: " + str(animated_sprite.visible))
			else:
				print("LaserBeam: AnimatedSprite2D is null")

	# Update collision shape position
	if collision_shape:
		collision_shape.position.x = max_length / 2

func activate(new_target: Node2D = null):
	# Don't activate if paused
	if is_paused:
		return
		
	print("LaserBeam: activate() called with target: " + str(new_target))
	target = new_target
	is_active = true

	# Show and play animation
	if animated_sprite:
		animated_sprite.visible = true
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("beam"):
			animated_sprite.play("beam")
			print("LaserBeam: Playing 'beam' animation")
		else:
			print("LaserBeam: WARNING - No 'beam' animation found")
	else:
		print("LaserBeam: ERROR - Cannot show beam, AnimatedSprite2D is null")

	# Enable collision
	if collision_area:
		collision_area.monitoring = true
		collision_area.monitorable = true
	else:
		print("LaserBeam: ERROR - Cannot enable collision, CollisionArea is null")

	# Start damage timer
	damage_timer.start()

	print("LaserBeam: Activated with target: " + str(target))

func deactivate():
	print("LaserBeam: deactivate() called")
	is_active = false
	target = null

	# Hide beam
	if animated_sprite:
		animated_sprite.visible = false
	else:
		print("LaserBeam: ERROR - Cannot hide beam, AnimatedSprite2D is null")

	# Hide hit effect
	if hit_effect:
		hit_effect.visible = false
	else:
		print("LaserBeam: WARNING - Cannot hide hit effect, HitEffect is null")

	# Disable collision
	if collision_area:
		collision_area.monitoring = false
		collision_area.monitorable = false
	else:
		print("LaserBeam: ERROR - Cannot disable collision, CollisionArea is null")

	# Stop damage timer
	damage_timer.stop()

	# Clear enemies hit list
	enemies_hit.clear()

	print("LaserBeam: Deactivated")

func _on_damage_timer_timeout():
	# Skip if paused or inactive
	if is_paused or not is_active:
		return

	# Apply damage to all enemies in the hit list
	for enemy in enemies_hit:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			var damage_amount = damage_per_second * damage_timer.wait_time
			print("LaserBeam: Applying " + str(damage_amount) + " damage to " + str(enemy.name))
			enemy.take_damage(damage_amount)

func _on_body_entered(body):
	# Skip if paused
	if is_paused:
		return
		
	print("LaserBeam: Body entered: " + body.name + ", is enemy: " + str(body.is_in_group("enemies")))

	if body.is_in_group("enemies") and not enemies_hit.has(body):
		print("LaserBeam: Adding enemy to hit list: " + body.name)
		enemies_hit.append(body)
		
		# Show hit effect at collision point if we have one
		if hit_effect:
			# Calculate approximate collision point
			var direction = Vector2(cos(rotation), sin(rotation))
			var distance = global_position.distance_to(body.global_position)
			var collision_point = global_position + direction * min(distance, max_length)
			
			hit_effect.global_position = collision_point
			hit_effect.visible = true
			if hit_effect is AnimatedSprite2D and hit_effect.sprite_frames:
				hit_effect.play("default")
		else:
			print("LaserBeam: WARNING - Cannot show hit effect, HitEffect is null")

func _on_body_exited(body):
	# Skip if paused
	if is_paused:
		return
		
	if enemies_hit.has(body):
		print("LaserBeam: Removing enemy from hit list: " + body.name)
		enemies_hit.erase(body)
		
		# Hide hit effect if no more enemies are being hit
		if enemies_hit.size() == 0 and hit_effect:
			hit_effect.visible = false

# Setter methods for external configuration
func set_damage(value: float):
	damage_per_second = value
	print("LaserBeam: Damage set to " + str(damage_per_second) + " per second")

func set_beam_width(width: float):
	beam_width = width
	if animated_sprite:
		animated_sprite.scale.y = beam_width
		print("LaserBeam: Beam width set to " + str(beam_width))
	else:
		print("LaserBeam: ERROR - Cannot set beam width, AnimatedSprite2D is null")

	# Update collision shape
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.extents.y = beam_width * 2
		print("LaserBeam: Collision shape height updated")
	else:
		print("LaserBeam: ERROR - Cannot update collision shape height")

func set_beam_color(color: Color):
	beam_color = color
	if animated_sprite:
		animated_sprite.modulate = color
		print("LaserBeam: Beam color set to " + str(beam_color))
	else:
		print("LaserBeam: ERROR - Cannot set beam color, AnimatedSprite2D is null")

func set_max_length(length: float):
	max_length = length
	if animated_sprite:
		animated_sprite.scale.x = max_length / 100.0
		print("LaserBeam: Beam length set to " + str(max_length))
	else:
		print("LaserBeam: ERROR - Cannot set beam length, AnimatedSprite2D is null")

	# Update collision shape
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.extents.x = max_length / 2
		collision_shape.position.x = max_length / 2
		print("LaserBeam: Collision shape width and position updated")
	else:
		print("LaserBeam: ERROR - Cannot update collision shape width and position")

# Add method to handle pause state
func set_paused(paused: bool):
	is_paused = paused
	
	if is_paused:
		# Pause animations
		if animated_sprite:
			animated_sprite.pause()
		if hit_effect and hit_effect is AnimatedSprite2D:
			hit_effect.pause()
			
		# Pause timer
		if damage_timer:
			damage_timer.paused = true
	else:
		# Resume animations
		if animated_sprite:
			animated_sprite.play()
		if hit_effect and hit_effect is AnimatedSprite2D and hit_effect.visible:
			hit_effect.play()
			
		# Resume timer
		if damage_timer:
			damage_timer.paused = false
	
	print("LaserBeam: Pause state set to " + str(paused))
