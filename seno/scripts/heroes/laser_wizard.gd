extends "res://scripts/heroes/heros_base.gd"

# Laser Wizard specific properties
@export var laser_beam_scene: PackedScene
@export var laser_damage_per_second: float = 10000.0
@export var laser_width: float = 7.0
@export var laser_color: Color = Color(1.0, 0.2, 0.2, 0.8)  # Red laser
@export var laser_max_length: float = 150.0
@export var laser_rotation_speed: float = 3.0  # Radians per second

# Node references specific to laser wizard
@onready var animated_sprite = $Visuals/AnimatedSprite2D
@onready var wand_tip = $Visuals/WandTip
@onready var laser_beam = null

# Original wand tip position
var original_wand_tip_position: Vector2

func _ready():
	# Set base hero properties
	hero_type = "laser_wizard"
	max_health = 60.0
	health = max_health
	attack_range = 250.0
	attack_speed = 1.0  # Attacks per second
	damage = laser_damage_per_second
	base_cost = 225

	# Store original wand tip position
	if wand_tip:
		original_wand_tip_position = wand_tip.position
	else:
		# Create wand tip if it doesn't exist
		wand_tip = Marker2D.new()
		wand_tip.name = "WandTip"
		wand_tip.position = Vector2(0, -20)  # Default position
		original_wand_tip_position = wand_tip.position
		$Visuals.add_child(wand_tip)

	# Create laser beam
	_create_laser_beam()

	# Call parent _ready function
	super._ready()
	

func _process(delta):
	# Call parent _process first
	super._process(delta)

	# Update wand tip position based on sprite flip
	_update_wand_tip_position()
	
	# Debug: Check if laser beam exists and is visible
	if Engine.get_frames_drawn() % 60 == 0:  # Check once per second
		if laser_beam:
			var visible_status = "unknown"
			if laser_beam.has_node("AnimatedSprite2D"):
				visible_status = str(laser_beam.get_node("AnimatedSprite2D").visible)
			elif laser_beam.has_node("Line2D"):
				visible_status = str(laser_beam.get_node("Line2D").visible)


func _create_laser_beam():
	
	# Try to load the laser beam scene
	var scene_path = "res://scenes/projectiles/laser_beam.tscn"
	var alt_scene_path = "res://scenes/projectiles/laser_beam_line.tscn"
	
	# First try the sprite-based laser beam
	if ResourceLoader.exists(scene_path):
		var beam_scene = load(scene_path)
		laser_beam = beam_scene.instantiate()
	# If that fails, try the Line2D-based laser beam
	elif ResourceLoader.exists(alt_scene_path):
		var beam_scene = load(alt_scene_path)
		laser_beam = beam_scene.instantiate()
	else:
		# Create a simple Line2D laser beam as fallback
		_create_fallback_laser_beam()
		return

	# Set laser beam properties
	if laser_beam.has_method("set_damage"):
		laser_beam.set_damage(laser_damage_per_second)
	elif "damage_per_second" in laser_beam:
		laser_beam.damage_per_second = laser_damage_per_second

	if laser_beam.has_method("set_beam_width"):
		laser_beam.set_beam_width(laser_width)
	elif "beam_width" in laser_beam:
		laser_beam.beam_width = laser_width

	if laser_beam.has_method("set_beam_color"):
		laser_beam.set_beam_color(laser_color)
	elif "beam_color" in laser_beam:
		laser_beam.beam_color = laser_color

	if laser_beam.has_method("set_max_length"):
		laser_beam.set_max_length(laser_max_length)
	elif "max_length" in laser_beam:
		laser_beam.max_length = laser_max_length

	# CRITICAL: Position the beam at exactly (0,0) relative to its parent
	laser_beam.position = Vector2.ZERO
	
	# Make sure the beam is visible when active
	if laser_beam.has_node("AnimatedSprite2D"):
		var sprite = laser_beam.get_node("AnimatedSprite2D")
		sprite.visible = false  # Initially invisible
	elif laser_beam.has_node("Line2D"):
		var line = laser_beam.get_node("Line2D")
		line.visible = false  # Initially invisible

	# Add to wand tip
	if wand_tip:
		wand_tip.add_child(laser_beam)
	else:
		$Visuals.add_child(laser_beam)

# Create a simple Line2D laser beam as fallback
func _create_fallback_laser_beam():
	
	# Create a new Node2D as the laser beam root
	laser_beam = Node2D.new()
	laser_beam.name = "FallbackLaserBeam"
	
	# Create a Line2D for the beam
	var line = Line2D.new()
	line.name = "Line2D"
	line.points = [Vector2.ZERO, Vector2(laser_max_length, 0)]
	line.width = laser_width
	line.default_color = laser_color
	line.visible = false  # Initially invisible
	laser_beam.add_child(line)
	
	# Create an Area2D for collision detection
	var area = Area2D.new()
	area.name = "CollisionArea"
	area.collision_layer = 0
	area.collision_mask = 2  # Layer 2 for enemies
	laser_beam.add_child(area)
	
	# Create a CollisionShape2D
	var shape = CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect_shape = RectangleShape2D.new()
	rect_shape.extents = Vector2(laser_max_length / 2, laser_width / 2)
	shape.shape = rect_shape
	shape.position.x = laser_max_length / 2  # Center the shape on the beam
	area.add_child(shape)
	
	# Create a Timer for damage application
	var timer = Timer.new()
	timer.name = "DamageTimer"
	timer.wait_time = 0.1
	timer.one_shot = false
	laser_beam.add_child(timer)
	
	# Add a script to the laser beam
	var script = GDScript.new()
	script.source_code = """
extends Node2D

var target: Node2D = null
var is_active: bool = false
var enemies_hit: Array = []
var damage_per_second: float = 30.0
var beam_width: float = 4.0
var beam_color: Color = Color(1.0, 0.2, 0.2, 0.8)
var max_length: float = 500.0

@onready var line = $Line2D
@onready var collision_area = $CollisionArea
@onready var collision_shape = $CollisionArea/CollisionShape2D
@onready var damage_timer = $DamageTimer

func _ready():
	# Connect signals
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	collision_area.body_entered.connect(_on_body_entered)
	collision_area.body_exited.connect(_on_body_exited)

func _process(delta):
	if not is_active:
		return
	
	# Update beam direction to point at target
	if target and is_instance_valid(target):
		var target_pos = target.global_position
		var direction = global_position.direction_to(target_pos)
		rotation = direction.angle()

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
	

func deactivate():
	is_active = false
	target = null
	
	# Hide line
	if line:
		line.visible = false
	
	# Disable collision
	if collision_area:
		collision_area.monitoring = false
		collision_area.monitorable = false
	
	# Stop damage timer
	damage_timer.stop()
	
	# Clear enemies hit list
	enemies_hit.clear()
	

func _on_damage_timer_timeout():
	if not is_active:
		return
	
	# Apply damage to all enemies in the hit list
	for enemy in enemies_hit:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			var damage_amount = damage_per_second * damage_timer.wait_time
			enemy.take_damage(damage_amount)

func _on_body_entered(body):
	if body.is_in_group("enemies") and not enemies_hit.has(body):
		enemies_hit.append(body)

func _on_body_exited(body):
	if enemies_hit.has(body):
		enemies_hit.erase(body)

# Setter methods
func set_damage(value: float):
	damage_per_second = value

func set_beam_width(width: float):
	beam_width = width
	if line:
		line.width = beam_width
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
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.extents.x = max_length / 2
		collision_shape.position.x = max_length / 2
"""
	script.reload()
	laser_beam.set_script(script)
	
	# Add to wand tip
	if wand_tip:
		wand_tip.add_child(laser_beam)
	else:
		$Visuals.add_child(laser_beam)

# Update wand tip position based on sprite flip
func _update_wand_tip_position():
	if wand_tip and animated_sprite and original_wand_tip_position != Vector2.ZERO:
		if animated_sprite.flip_h:
			# If sprite is flipped horizontally (facing left), mirror the wand tip position
			wand_tip.position.x = -original_wand_tip_position.x
		else:
			# If sprite is not flipped (facing right), use original position
			wand_tip.position.x = original_wand_tip_position.x

# Override perform_attack to implement laser wizard specific attack
func perform_attack():
	if not target_enemy or not is_instance_valid(target_enemy):
		return

	# Skip enemies that are dying
	if target_enemy.has_method("is_dying") and target_enemy.is_dying:
		target_enemy = null
		stop_attack()
		return


	# Face the enemy
	if animated_sprite and target_enemy:
		animated_sprite.flip_h = target_enemy.global_position.x < global_position.x
		# Update wand tip position immediately
		_update_wand_tip_position()

	# Play attack animation
	if animated_sprite:
		animated_sprite.play("attack1")

	# Activate laser beam
	if laser_beam and laser_beam.has_method("activate"):
		laser_beam.activate(target_enemy)
		is_attacking = true

	# Emit signal
	emit_signal("attack_performed", target_enemy)

# Override stop_attack to deactivate laser
func stop_attack():
	super.stop_attack()

	if laser_beam and laser_beam.has_method("deactivate"):
		laser_beam.deactivate()

# Override die to clean up laser
func die():
	if laser_beam and laser_beam.has_method("deactivate"):
		laser_beam.deactivate()

	super.die()
