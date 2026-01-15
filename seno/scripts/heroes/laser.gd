extends Node2D

@export var max_length: float = 500.0
@export var damage_per_second: float = 30.0
@export var beam_width: float = 4.0
@export var beam_color: Color = Color(1.0, 0.2, 0.2, 0.8)

var target: Node2D = null
var is_active: bool = false
var enemies_hit: Array = []

@onready var line: Line2D = $Line2D
@onready var hit_effect = $HitEffect
@onready var damage_timer = $DamageTimer
@onready var collision_area = $CollisionArea
@onready var collision_shape = $CollisionArea/CollisionShape2D

func _ready():
	# Create Line2D if it doesn't exist
	if not line:
		line = Line2D.new()
		line.name = "Line2D"
		add_child(line)
	
	# Set up Line2D
	line.width = beam_width
	line.default_color = beam_color
	line.points = [Vector2.ZERO, Vector2(max_length, 0)]
	line.visible = false
	
	# Set up damage timer
	damage_timer.wait_time = 0.1
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	
	# Connect collision signals
	if collision_area:
		collision_area.body_entered.connect(_on_body_entered)
		collision_area.body_exited.connect(_on_body_exited)
	
	# Set collision shape size
	if collision_shape:
		var rect_shape = RectangleShape2D.new()
		rect_shape.extents = Vector2(max_length / 2, beam_width)
		collision_shape.shape = rect_shape
		collision_shape.position.x = max_length / 2  # Center the shape on the beam
	
	print("LaserBeam: Ready with damage_per_second: " + str(damage_per_second))

func _process(delta):
	if not is_active:
		return
	
	# Update beam direction to point at target
	if target and is_instance_valid(target):
		var target_pos = target.global_position
		var direction = global_position.direction_to(target_pos)
		rotation = direction.angle()
		
		# Check for collisions to adjust beam length
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.new()
		query.from = global_position
		query.to = global_position + Vector2(cos(rotation), sin(rotation)) * max_length
		query.collision_mask = 2  # Enemy layer
		var result = space_state.intersect_ray(query)
		
		if result:
			var collision_point = result.position
			var distance = global_position.distance_to(collision_point)
			line.points[1] = Vector2(distance, 0)
			
			# Update collision shape
			if collision_shape:
				collision_shape.position.x = distance / 2
				if collision_shape.shape is RectangleShape2D:
					collision_shape.shape.extents.x = distance / 2
		else:
			line.points[1] = Vector2(max_length, 0)
			
			# Reset collision shape
			if collision_shape:
				collision_shape.position.x = max_length / 2
				if collision_shape.shape is RectangleShape2D:
					collision_shape.shape.extents.x = max_length / 2

func activate(new_target: Node2D = null):
	target = new_target
	is_active = true
	
	# Show line
	if line:
		line.visible = true
	
	# Enable collision
	if collision_area:
		collision_area.monitoring = true
		collision_area.monitorable = true
	
	# Start damage timer
	damage_timer.start()
	
	print("LaserBeam: Activated with target: " + str(target))

func deactivate():
	is_active = false
	target = null
	
	# Hide line
	if line:
		line.visible = false
	
	# Hide hit effect
	if hit_effect:
		hit_effect.visible = false
	
	# Disable collision
	if collision_area:
		collision_area.monitoring = false
		collision_area.monitorable = false
	
	# Stop damage timer
	damage_timer.stop()
	
	# Clear enemies hit list
	enemies_hit.clear()
	
	print("LaserBeam: Deactivated")

func _on_damage_timer_timeout():
	if not is_active:
		return
	
	# Apply damage to all enemies in the hit list
	for enemy in enemies_hit:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			var damage_amount = damage_per_second * damage_timer.wait_time
			print("LaserBeam: Applying " + str(damage_amount) + " damage to " + str(enemy.name))
			enemy.take_damage(damage_amount)

func _on_body_entered(body):
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

func _on_body_exited(body):
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
	if line:
		line.width = beam_width
	
	# Update collision shape
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.extents.y = beam_width / 2

func set_beam_color(color: Color):
	beam_color = color
	if line:
		line.default_color = color

func set_max_length(length: float):
	max_length = length
	if line:
		line.points[1] = Vector2(max_length, 0)
	
	# Update collision shape
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.extents.x = max_length / 2
		collision_shape.position.x = max_length / 2
