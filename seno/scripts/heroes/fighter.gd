extends "res://scripts/heroes/heros_base.gd"

# Fighter specific properties
@export var attack_damage_multiplier: float = 1.5  # Higher damage multiplier for melee attacks
@export var combo_attack: bool = true  # Can perform combo attacks
@export var combo_hits: int = 2  # Number of hits in combo
@export var knockback_strength: float = 10.0  # Strength of knockback effect

# Node references specific to fighter
@onready var animated_sprite = $Visuals/AnimatedSprite2D
@onready var melee_attack_area = $AttackArea
@onready var attack_collision = $AttackArea/CollisionShape2D
@onready var combo_timer = Timer.new()

# Combat state
var current_combo: int = 0
var is_combo_active: bool = false
var enemies_in_range: Array = []

func _ready():
	# Set base hero properties through assignment
	hero_type = "fighter"
	max_health = 150.0  # Higher health than wizards
	health = max_health
	attack_range = 80.0  # Much shorter range than wizards
	attack_speed = 1.5  # Faster attack speed
	damage = 35.0  # Higher base damage
	base_cost = 250  # Standard cost
	
	# Create and configure combo timer
	combo_timer.one_shot = true
	combo_timer.wait_time = 1.0  # Time window to continue combo
	combo_timer.timeout.connect(_on_combo_timer_timeout)
	add_child(combo_timer)
	
	# Enable attack collision - CHANGED: Enable by default
	if attack_collision:
		attack_collision.disabled = false
	# Call parent _ready function
	super._ready()
	
	if melee_attack_area:
		# Disconnect existing connections to avoid duplicates
		if melee_attack_area.body_entered.is_connected(_on_attack_area_body_entered):
			melee_attack_area.body_entered.disconnect(_on_attack_area_body_entered)
		if melee_attack_area.body_exited.is_connected(_on_attack_area_body_exited):
			melee_attack_area.body_exited.disconnect(_on_attack_area_body_exited)
			
		# Connect signals
		melee_attack_area.body_entered.connect(_on_attack_area_body_entered)
		melee_attack_area.body_exited.connect(_on_attack_area_body_exited)
		
		# ADDED: Make sure monitoring is enabled
		melee_attack_area.monitoring = true
		melee_attack_area.monitorable = true
		
	
	# Make sure we're in the heroes group
	if not is_in_group("heroes"):
		add_to_group("heroes")
	
	# Make sure we're in the heros group (with typo, as seen in enemy code)
	if not is_in_group("heros"):
		add_to_group("heros")
	
	# ADDED: Set collision mask to detect enemies (layer 2)
	if melee_attack_area:
		melee_attack_area.collision_mask = 2  # Layer 2 for enemies
	
	# ADDED: Initial check for enemies in range
	call_deferred("_check_for_enemies_in_range")

# ADDED: Function to check for enemies in range
func _check_for_enemies_in_range():
	if melee_attack_area:
		var bodies = melee_attack_area.get_overlapping_bodies()
		
		for body in bodies:
			if body.is_in_group("enemies"):
				_on_attack_area_body_entered(body)

# Override take_damage to add debug prints
func take_damage(amount: float):
	# Call the parent method to handle the actual damage
	super.take_damage(amount)

# Add a take_damage_hero method for compatibility with enemy code
func take_damage_hero(amount: float):
	take_damage(amount)

# Override perform_attack to implement fighter specific attack
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
	
	# Determine which attack animation to play based on combo state
	var attack_anim = "attack1"
	if combo_attack and is_combo_active:
		current_combo = (current_combo + 1) % combo_hits
		if current_combo == 1:
			attack_anim = "attack2"
	
	# Play attack animation
	if animated_sprite:
		animated_sprite.play(attack_anim)
	
	# Apply damage directly
	_apply_damage_to_enemies_in_range()
	
	# Start or reset combo timer
	if combo_attack:
		is_combo_active = true
		combo_timer.start()
	
	# Emit signal
	emit_signal("attack_performed", target_enemy)

# Apply damage to all enemies in attack range
func _apply_damage_to_enemies_in_range():
	# Get all enemies in the attack area
	var bodies = []
	if melee_attack_area:
		bodies = melee_attack_area.get_overlapping_bodies()
	else:
		return
	
	var enemies_hit = 0
	
	for body in bodies:
		if body.is_in_group("enemies"):
			# Skip enemies that are dying
			if body.has_method("is_dying") and body.is_dying:
				continue
			
			enemies_hit += 1
			
			# Calculate damage (possibly increased for combo hits)
			var hit_damage = damage
			if combo_attack and current_combo > 0:
				hit_damage *= (1.0 + (current_combo * 0.25))  # Increase damage for combo hits
			
			# Apply damage
			if body.has_method("take_damage"):
				body.take_damage(hit_damage)
			_apply_knockback(body)
	
# Apply knockback to an enemy
func _apply_knockback(enemy: Node2D):
	if not enemy.has_method("apply_knockback"):
		return
	
	var direction = enemy.global_position - global_position
	direction = direction.normalized()
	
	# Calculate knockback strength (possibly increased for combo hits)
	var strength = knockback_strength
	if combo_attack and current_combo > 0:
		strength *= (1.0 + (current_combo * 0.2))  # Increase knockback for combo hits
	
	enemy.apply_knockback(direction, strength)

# Called when the combo timer times out
func _on_combo_timer_timeout():
	is_combo_active = false
	current_combo = 0

# Override stop_attack to also reset combo
func stop_attack():
	super.stop_attack()
	is_combo_active = false
	current_combo = 0
	combo_timer.stop()

# Track enemies entering attack range
func _on_attack_area_body_entered(body: Node2D):
	if body.is_in_group("enemies"):
		if not enemies_in_range.has(body):
			enemies_in_range.append(body)
			
			# ADDED: Set as target if we don't have one
			if target_enemy == null or not is_instance_valid(target_enemy):
				target_enemy = body
				
				# Start attacking if we can
				if can_attack and not is_moving:
					perform_attack()

# Track enemies leaving attack range
func _on_attack_area_body_exited(body: Node2D):
	if body.is_in_group("enemies"):
		if enemies_in_range.has(body):
			enemies_in_range.erase(body)
		
		# If this was our target, find a new one
		if body == target_enemy:
			target_enemy = null
			_find_new_target()

# ADDED: Find a new target from enemies in range
func _find_new_target():
	if enemies_in_range.size() > 0:
		var closest_enemy = null
		var closest_distance = attack_range
		
		for enemy in enemies_in_range:
			if is_instance_valid(enemy):
				var distance = global_position.distance_to(enemy.global_position)
				if distance < closest_distance:
					closest_distance = distance
					closest_enemy = enemy
		
		if closest_enemy:
			target_enemy = closest_enemy
			
			# Start attacking immediately if we can
			if can_attack and not is_moving:
				perform_attack()

# Override _process to handle attack area monitoring
func _process(delta):
	# Call parent _process first
	super._process(delta)
	
	# Skip if paused or dying
	if is_paused or is_dying:
		return
	
	# Debug: Periodically check for enemies in range
	if Engine.get_frames_drawn() % 30 == 0:  # Check more frequently (every half second)
		if melee_attack_area:
			var bodies = melee_attack_area.get_overlapping_bodies()
			var enemy_count = 0
			for body in bodies:
				if body.is_in_group("enemies"):
					enemy_count += 1
					# ADDED: If we find an enemy and don't have it in our list, add it
					if not enemies_in_range.has(body):
						_on_attack_area_body_entered(body)
			

	# Clean up invalid enemies from the list
	for i in range(enemies_in_range.size() - 1, -1, -1):
		if not is_instance_valid(enemies_in_range[i]):
			enemies_in_range.remove_at(i)
	
	# If we have enemies in range but no target, set the closest one as target
	if enemies_in_range.size() > 0 and (target_enemy == null or not is_instance_valid(target_enemy)):
		_find_new_target()
	
	# ADDED: If we have a target and can attack, do it!
	if target_enemy and is_instance_valid(target_enemy) and can_attack and not is_moving:
		var distance = global_position.distance_to(target_enemy.global_position)
		if distance <= attack_range:
			perform_attack()
