extends "res://scripts/heroes/heros_base.gd"

# Healer specific properties
@export var heal_amount: float = 15.0
@export var heal_projectile_scene: PackedScene

var target_ally: Node2D = null
var allies_in_range = []
var ally_health_states = {}  # Track ally health to detect damage

@onready var ally_detection_area = $AllyDetectionArea
var heal_timer: Timer

func _ready():
	# Set base class properties
	hero_type = "healer"
	attack_range = 200.0
	attack_speed = 0.8
	damage = -heal_amount  # Negative damage = healing
	max_health = 60.0
	health = max_health
	move_speed = 80.0
	base_cost = 250
	sell_value_percent = 0.7
	
	# Initialize timers
	heal_timer = $HealTimer
	if not heal_timer:
		heal_timer = Timer.new()
		heal_timer.name = "HealTimer"
		heal_timer.one_shot = true
		add_child(heal_timer)
		print("Healer: Created missing HealTimer")

	heal_timer.wait_time = 1.0 / attack_speed
	heal_timer.timeout.connect(_on_heal_timer_timeout)
	
	# Connect ally detection signals
	if ally_detection_area:
		# Make sure we're detecting heroes on the correct layer
		ally_detection_area.collision_layer = 0
		ally_detection_area.collision_mask = 1  # Layer 1 for heroes (updated from 4)
		
		if not ally_detection_area.body_entered.is_connected(_on_ally_entered):
			ally_detection_area.body_entered.connect(_on_ally_entered)
		if not ally_detection_area.body_exited.is_connected(_on_ally_exited):
			ally_detection_area.body_exited.connect(_on_ally_exited)
	else:
		print("Healer: WARNING - ally_detection_area node not found, ally detection will not work")
		ally_detection_area = Area2D.new()
		ally_detection_area.name = "AllyDetectionArea"
		ally_detection_area.collision_layer = 0
		ally_detection_area.collision_mask = 1  # Layer 1 for heroes (updated from 4)
		add_child(ally_detection_area)
		
		var collision_shape = CollisionShape2D.new()
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = attack_range  # Use attack_range for consistency
		collision_shape.shape = circle_shape
		ally_detection_area.add_child(collision_shape)
		
		ally_detection_area.body_entered.connect(_on_ally_entered)
		ally_detection_area.body_exited.connect(_on_ally_exited)
		print("Healer: Created missing AllyDetectionArea with radius " + str(attack_range))
	
	# Check if heal_projectile_scene is assigned
	if not heal_projectile_scene:
		print("Healer: WARNING - heal_projectile_scene is not assigned!")
	
	# Call parent _ready to set up pathfinding and other base functionality
	super._ready()
	
	# Immediately scan for allies that need healing
	call_deferred("scan_for_allies_needing_healing")
	
	print("Healer: Ready with heal amount: " + str(heal_amount))

func _process(delta):
	# Skip if paused or dying
	if is_paused or is_dying:
		return
		
	# Check allies health to see if any need healing
	check_allies_health()
	
	# If we have a target ally and can heal, start healing
	if target_ally and can_attack and not is_moving:
		play_heal_animation()
		_heal()

func scan_for_allies_needing_healing():
	# Force an immediate scan for allies that need healing
	print("Healer: Scanning for allies needing healing")
	allies_in_range = []
	
	# Get all heroes in the scene
	var heroes = get_tree().get_nodes_in_group("heroes")
	for hero in heroes:
		if hero != self:  # Don't include self
			var distance = global_position.distance_to(hero.global_position)
			if distance <= attack_range:
				allies_in_range.append(hero)
				ally_health_states[hero] = hero.health
				print("Healer: Found ally in range: " + hero.name + " with health " + str(hero.health) + "/" + str(hero.max_health))
	
	# Find ally with lowest health percentage
	check_allies_health()

func check_allies_health():
	# Update our list of allies in range
	if ally_detection_area:
		allies_in_range = ally_detection_area.get_overlapping_bodies()
	
	# Clean up the allies list to remove any freed instances
	var valid_allies = []
	for ally in allies_in_range:
		if is_instance_valid(ally) and ally.is_in_group("heroes") and ally != self:
			valid_allies.append(ally)
	allies_in_range = valid_allies
	
	# Find ally with lowest health percentage
	var lowest_health_ally = null
	var lowest_health_percent = 1.0  # 100%
	
	for ally in allies_in_range:
		# Skip if ally is at full health
		if ally.health >= ally.max_health:
			continue
			
		# Calculate health percentage
		var health_percent = ally.health / ally.max_health
			
		# If this ally has lower health than our current target
		if health_percent < lowest_health_percent:
			lowest_health_percent = health_percent
			lowest_health_ally = ally
			print("Healer: Found ally needing healing: " + ally.name + " with health " + str(ally.health) + "/" + str(ally.max_health))
	
	# Check if current target is still valid
	if target_ally and not is_instance_valid(target_ally):
		print("Healer: Current target is no longer valid")
		target_ally = null
	
	# Set new target
	if lowest_health_ally != target_ally:
		target_ally = lowest_health_ally
		if target_ally:
			print("Healer: New target ally: " + target_ally.name)
		else:
			print("Healer: No allies need healing")

func _heal():
	if not is_instance_valid(target_ally) or is_moving:
		if target_ally and not is_instance_valid(target_ally):
			print("Healer: Target ally is no longer valid, finding new target")
			target_ally = null
			check_allies_health()
		return
		
	# Skip if ally is at full health
	if target_ally.health >= target_ally.max_health:
		print("Healer: Target ally is at full health, finding new target")
		target_ally = null
		check_allies_health()
		return
		
	print("Healer: Performing heal on " + target_ally.name)
	can_attack = false
	heal_timer.start()
	
	# If we have a heal projectile scene, use it
	if heal_projectile_scene:
		# Create a timer for when the projectile should be created
		var projectile_timer = get_tree().create_timer(0.3)
		projectile_timer.timeout.connect(create_heal_projectile)
	else:
		# Direct heal without projectile
		direct_heal_ally()

func direct_heal_ally():
	if not is_instance_valid(target_ally):
		print("Healer: Target ally is no longer valid for direct healing")
		target_ally = null
		return
		
	# Skip if ally is at full health
	if target_ally.health >= target_ally.max_health:
		target_ally = null
		return
		
	print("Healer: Direct healing ally " + target_ally.name + " for " + str(heal_amount))
	
	# Use the heal method directly
	if target_ally.has_method("heal"):
		target_ally.heal(heal_amount)
		
		# Create a visual effect to show the healing
		create_heal_effect_at_ally()
	else:
		print("Healer: ERROR - Target ally doesn't have heal method!")

func create_heal_effect_at_ally():
	if not is_instance_valid(target_ally):
		print("Healer: Target ally is no longer valid for creating heal effect")
		return
		
	# Create particles for heal effect
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.6
	particles.amount = 16
	particles.lifetime = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 90
	particles.gravity = Vector2(0, -20)  # Particles rise up
	particles.initial_velocity_min = 10
	particles.initial_velocity_max = 30
	particles.scale_amount_min = 2
	particles.scale_amount_max = 4
	particles.color = Color(0.2, 0.9, 0.4)  # Green healing color
	
	# Add particles to the scene instead of as a child of the target
	get_parent().add_child(particles)
	particles.global_position = target_ally.global_position
	
	# Auto-remove particles after they finish
	var timer = Timer.new()
	timer.wait_time = 1.5
	timer.one_shot = true
	timer.timeout.connect(func(): 
		particles.queue_free()
		timer.queue_free()
	)
	particles.add_child(timer)
	timer.start()

func create_heal_projectile():
	if not is_instance_valid(target_ally) or is_moving:
		print("Healer: Target ally is no longer valid for creating heal projectile")
		target_ally = null
		return
		
	# Skip if ally is at full health
	if target_ally.health >= target_ally.max_health:
		target_ally = null
		return
		
	if not heal_projectile_scene:
		print("Healer: ERROR - heal_projectile_scene is not assigned!")
		direct_heal_ally()  # Fallback to direct healing
		return
		
	print("Healer: Created heal projectile for " + target_ally.name)
	var heal_proj = heal_projectile_scene.instantiate()
	
	# Use the spawn point if it exists, otherwise use the healer's position
	var spawn_position = global_position
	if has_node("Visuals/ProjectileSpawnPoint"):
		spawn_position = $Visuals/ProjectileSpawnPoint.global_position
		print("Healer: Using ProjectileSpawnPoint at " + str(spawn_position))
	else:
		# If no spawn point, use a position slightly in front of the healer based on facing direction
		var offset = Vector2(20, -10)  # Default offset for facing right
		if animation and animation.flip_h:
			offset.x = -20  # Flip offset if facing left
		spawn_position = global_position + offset
		print("Healer: Using calculated spawn position at " + str(spawn_position))
	
	heal_proj.global_position = spawn_position
	
	# Set projectile properties - works with the user's script
	heal_proj.target = target_ally
	heal_proj.heal_amount = heal_amount
	
	get_parent().add_child(heal_proj)

func _on_heal_timer_timeout():
	can_attack = true
	
	# Check if we should continue healing the same target
	if is_instance_valid(target_ally):
		if target_ally.health < target_ally.max_health:
			# Continue healing
			play_heal_animation()
			_heal()
		else:
			# Target is fully healed, find a new target
			print("Healer: Target fully healed, finding new target")
			target_ally = null
			check_allies_health()
	else:
		# Target is no longer valid, find a new target
		print("Healer: Target is no longer valid, finding new target")
		target_ally = null
		check_allies_health()

func _on_ally_entered(body):
	if is_moving:
		return
		
	if body.is_in_group("heroes") and body != self:
		print("Healer: Ally entered range: " + body.name)
		
		# Store initial health state
		ally_health_states[body] = body.health
		
		# If we don't have a target and this ally needs healing, target them
		if target_ally == null and body.health < body.max_health:
			target_ally = body
			can_attack = true
			print("Healer: New target ally: " + target_ally.name)

func _on_ally_exited(body):
	if body == target_ally:
		print("Healer: Target ally left range")
		target_ally = null
		stop_attack()
		
		# Find a new target
		check_allies_health()
		
	# Remove from health tracking
	if ally_health_states.has(body):
		ally_health_states.erase(body)

func play_heal_animation():
	if not animation:
		return
		
	if target_ally:
		animation.flip_h = target_ally.global_position.x < global_position.x
	if animation.animation != attack_animation:
		animation.play(attack_animation)

# Override the parent's find_target_enemy method to do nothing
# since we're not targeting enemies
func find_target_enemy():
	pass

# Override perform_attack to do nothing since we're using our own healing system
func perform_attack():
	pass
