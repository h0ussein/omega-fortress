extends CharacterBody2D

# Basic properties
@export var move_speed: float = 80.0
@export var health: float = 180.0
@export var max_health: float = 180.0
@export var damage: float = 30.0
@export var attack_cooldown: float = 1.2
@export var gold_value: int = 30
@export var barrier_damage_multiplier: float = 3.0  # Does extra damage to barriers

# Target references
var target_base: Node2D = null
var target_hero: Node2D = null
var target_barrier: Node2D = null

# State tracking
var is_dying: bool = false
var is_paused: bool = false
var is_slowed: bool = false
var slow_amount: float = 0.0
var original_speed: float = 0.0

# Components
var health_bar = null
@onready var animation = $Visuals/AnimatedSprite2D
@onready var attack_area = $AttackArea
@onready var attack_hero_timer = $AttackHero
@onready var attack_base_timer = $AttackBase

# Timers
var slow_timer: Timer = null

signal died(enemy)

func _ready():
	# Add to enemies group
	add_to_group("enemies")
	
	# Store original speed
	original_speed = move_speed
	
	# Create health bar
	create_health_bar()
	
	# Find the base
	target_base = get_tree().get_first_node_in_group("base")
	if target_base:
		print("Enemy8: Found base at " + str(target_base.global_position))
	else:
		print("Enemy8: ERROR - Base not found!")
	
	# Set up timers
	setup_timers()
	
	# Set up attack timers
	if attack_hero_timer:
		attack_hero_timer.wait_time = attack_cooldown
		attack_hero_timer.timeout.connect(_on_attack_hero_timeout)
	else:
		print("Enemy8: ERROR - AttackHero timer not found!")
	
	if attack_base_timer:
		attack_base_timer.wait_time = attack_cooldown
		attack_base_timer.timeout.connect(_on_attack_base_timeout)
	else:
		print("Enemy8: ERROR - AttackBase timer not found!")
	
	# Connect area signals
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)
		print("Enemy8: Connected area signals")
	else:
		print("Enemy8: ERROR - AttackArea not found!")
	
	# Initialize animation
	if animation:
		animation.play("run")
	
	print("Enemy8: Ready with health: " + str(health) + "/" + str(max_health))

func setup_timers():
	# Create slow effect timer
	slow_timer = Timer.new()
	slow_timer.one_shot = true
	slow_timer.timeout.connect(_on_slow_timer_timeout)
	add_child(slow_timer)

func create_health_bar():
	# Create a ProgressBar node for the health bar
	var new_health_bar = ProgressBar.new()
	new_health_bar.name = "HealthBar"
	
	# Set size and position
	new_health_bar.custom_minimum_size = Vector2(30, 5)
	new_health_bar.position = Vector2(-15, -30)  # Position above the enemy
	
	# Set up the health bar properties
	new_health_bar.max_value = max_health
	new_health_bar.value = health
	new_health_bar.show_percentage = false
	
	# Style the health bar
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.8, 0.2)  # Green
	style_box.corner_radius_top_left = 1
	style_box.corner_radius_top_right = 1
	style_box.corner_radius_bottom_right = 1
	style_box.corner_radius_bottom_left = 1
	new_health_bar.add_theme_stylebox_override("fill", style_box)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray background
	bg_style.corner_radius_top_left = 1
	bg_style.corner_radius_top_right = 1
	bg_style.corner_radius_bottom_right = 1
	bg_style.corner_radius_bottom_left = 1
	new_health_bar.add_theme_stylebox_override("background", bg_style)
	
	# Add the health bar to the enemy
	add_child(new_health_bar)
	health_bar = new_health_bar
	
	print("Enemy8: Created health bar")

func _physics_process(delta):
	# Skip if dying or paused
	if is_dying or is_paused:
		return
	
	# Reset velocity at the start of each frame
	velocity = Vector2.ZERO
	
	# Handle different target priorities
	if target_barrier and is_instance_valid(target_barrier):
		# Stop moving and face the barrier when attacking
		$Visuals.scale.x = sign(target_barrier.global_position.x - global_position.x)
	elif target_hero and is_instance_valid(target_hero):
		# Stop moving and face the hero when attacking
		$Visuals.scale.x = sign(target_hero.global_position.x - global_position.x)
	elif target_base and is_instance_valid(target_base):
		# DIRECT MOVEMENT: Always move directly toward the base
		var direction = global_position.direction_to(target_base.global_position)
		
		# Apply slow effect if active
		var current_speed = move_speed
		if is_slowed:
			current_speed = move_speed * (1.0 - slow_amount)
		
		# Set velocity directly toward base
		velocity = direction * current_speed
		
		# Update visuals based on movement direction
		$Visuals.scale.x = -1 if direction.x > 0 else 1
	
	# Move the enemy
	if velocity.length() > 0:
		move_and_slide()

# Attack barrier
func attack_barrier():
	if is_dying or is_paused:
		return
	
	if not target_barrier or not is_instance_valid(target_barrier):
		print("Enemy8: Target barrier no longer exists")
		# Clean up the target and timer
		target_barrier = null
		var barrier_timer = get_node_or_null("BarrierAttackTimer")
		if barrier_timer:
			barrier_timer.stop()
			barrier_timer.queue_free()
		
		# Resume movement
		move_speed = original_speed
		if animation and target_hero == null:
			animation.play("run")
		return
	
	print("Enemy8: Attacking barrier")
	if target_barrier.has_method("take_damage"):
		# Apply barrier damage multiplier
		var barrier_damage = damage * barrier_damage_multiplier
		target_barrier.take_damage(barrier_damage)
		print("Enemy8: Dealt " + str(barrier_damage) + " damage to barrier")
		
		# Connect to the barrier's destroyed signal if not already connected
		if target_barrier.has_signal("barrier_destroyed") and not target_barrier.is_connected("barrier_destroyed", _on_barrier_destroyed):
			target_barrier.barrier_destroyed.connect(_on_barrier_destroyed)

func _on_attack_base_timeout():
	if is_dying or is_paused:
		return
	
	if target_base and is_instance_valid(target_base):
		if target_base.has_method("take_damage_base"):
			target_base.take_damage_base(damage)
	else:
		if attack_base_timer:
			attack_base_timer.stop()

func _on_attack_hero_timeout():
	if is_dying or is_paused:
		return
	
	if target_hero and is_instance_valid(target_hero):
		print("Enemy8: Attacking hero for " + str(damage) + " damage")
		if target_hero.has_method("take_damage_hero"):
			target_hero.take_damage_hero(damage)
		elif target_hero.has_method("take_damage"):
			target_hero.take_damage(damage)
	else:
		if attack_hero_timer:
			attack_hero_timer.stop()

# Apply slow effect to the enemy
func apply_slow(amount: float, duration: float):
	# Skip if paused
	if is_paused:
		return
		
	# Store the original speed if this is a new slow effect
	if not is_slowed:
		original_speed = move_speed
	
	# Apply the strongest slow effect
	if amount > slow_amount:
		slow_amount = amount
		print("Enemy8: Slowed by " + str(slow_amount * 100) + "% for " + str(duration) + " seconds")
	
	# Set or extend the duration
	is_slowed = true
	
	# Update visual indication of being slowed
	modulate = Color(0.7, 0.9, 1.0)  # Light blue tint
	
	# Reset and start the timer
	slow_timer.stop()
	slow_timer.wait_time = duration
	slow_timer.start()

# Called when slow effect expires
func _on_slow_timer_timeout():
	is_slowed = false
	slow_amount = 0.0
	
	# Reset visual indication
	modulate = Color(1, 1, 1)  # Normal color
	
	print("Enemy8: Slow effect expired")

func take_damage(amount: float):
	if is_dying or is_paused:
		return  # Don't take damage if already dying or paused
	
	health -= amount
	
	# Update health bar
	if health_bar:
		health_bar.value = health
		
		# Update health bar color based on health percentage
		var health_percent = health / max_health
		var style_box = health_bar.get_theme_stylebox("fill", "")
		
		if style_box is StyleBoxFlat:
			if health_percent > 0.6:
				style_box.bg_color = Color(0.2, 0.8, 0.2)  # Green
			elif health_percent > 0.3:
				style_box.bg_color = Color(0.9, 0.7, 0.1)  # Yellow/Orange
			else:
				style_box.bg_color = Color(0.9, 0.2, 0.2)  # Red
	
	# Visual feedback for taking damage
	flash_damage()
	
	if health <= 0:
		start_death()
	else:
		# Play hit animation
		if animation:
			animation.play("hit")
			await animation.animation_finished
			# Return to previous animation
			if target_barrier and is_instance_valid(target_barrier):
				animation.play("attack1")
			elif target_hero and is_instance_valid(target_hero):
				animation.play("attack1")
			else:
				animation.play("run")

func flash_damage():
	# Flash red when taking damage
	modulate = Color(1.5, 0.5, 0.5)  # Red tint
	
	# Create a tween to restore normal color
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.3)
	
	# If slowed, restore to the slow tint
	if is_slowed:
		tween.tween_property(self, "modulate", Color(0.7, 0.9, 1.0), 0.1)

func start_death():
	if is_dying:
		return  # Prevent multiple death calls
	
	is_dying = true
	
	# Stop all movement
	velocity = Vector2.ZERO
	move_speed = 0
	
	# Stop attack timers
	if attack_hero_timer:
		attack_hero_timer.stop()
	if attack_base_timer:
		attack_base_timer.stop()
	
	var barrier_timer = get_node_or_null("BarrierAttackTimer")
	if barrier_timer:
		barrier_timer.stop()
		barrier_timer.queue_free()
	
	# Stop slow timer
	if slow_timer:
		slow_timer.stop()
	
	# Remove from enemies group so heroes stop targeting
	remove_from_group("enemies")
	
	# Disable collision
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	
	# Disable attack area
	if attack_area and attack_area.has_node("CollisionShape2D"):
		attack_area.get_node("CollisionShape2D").set_deferred("disabled", true)
	
	# Emit died signal
	emit_signal("died", self)
	
	# Play death animation
	if animation:
		animation.play("die")
		await animation.animation_finished
	
	# Give gold to player
	var main_scene = get_node_or_null("/root/Node2D_main")
	if main_scene and is_instance_valid(main_scene):
		main_scene.gold += gold_value
		main_scene.update_gold_display()
		print("Enemy8: Gave " + str(gold_value) + " gold to player")
	
	# Remove from scene
	queue_free()

func _on_attack_area_body_entered(body: Node2D) -> void:
	if is_dying or is_paused:
		return
	
	# Check for heroes
	if (body.is_in_group("heroes") or body.is_in_group("heros")) and target_hero == null:
		print("Enemy8: Hero entered attack range: " + body.name)
		target_hero = body
		move_speed = 0
		if animation:
			animation.play("attack1")
		if attack_hero_timer and attack_hero_timer.is_stopped():
			attack_hero_timer.start()
			# Immediately deal first damage
			if target_hero and target_hero.has_method("take_damage") and not is_paused:
				print("Enemy8: Initial attack on hero for " + str(damage) + " damage")
				target_hero.take_damage(damage)
	
	# Check for base
	elif body.is_in_group("base"):
		move_speed = 0
		if animation:
			animation.play("attack1")
		if attack_base_timer and attack_base_timer.is_stopped():
			attack_base_timer.start()
	
	# Check for barriers - ONLY if we don't already have a barrier target
	elif (body.is_in_group("barriers") or (body.get_parent() and body.get_parent().is_in_group("barriers"))) and target_barrier == null:
		print("Enemy8: Targeting barrier for attack")
		target_barrier = body if body.is_in_group("barriers") else body.get_parent()
		move_speed = 0
		if animation:
			animation.play("attack1")
		
		# Start attacking the barrier immediately
		attack_barrier()
		
		# Set up a timer for continuous barrier attacks
		var barrier_timer = Timer.new()
		barrier_timer.name = "BarrierAttackTimer"
		barrier_timer.wait_time = attack_cooldown
		barrier_timer.one_shot = false
		barrier_timer.timeout.connect(attack_barrier)
		add_child(barrier_timer)
		barrier_timer.start()

func _on_attack_area_body_exited(body: Node2D) -> void:
	if is_dying or is_paused:
		return
	
	# Hero exited
	if body == target_hero:
		target_hero = null
		move_speed = original_speed
		if attack_hero_timer:
			attack_hero_timer.stop()
		if animation and target_barrier == null:  # Only switch to run if not attacking barrier
			animation.play("run")
	
	# Base exited
	elif body.is_in_group("base"):
		move_speed = original_speed
		if attack_base_timer:
			attack_base_timer.stop()
		if animation and target_barrier == null:  # Only switch to run if not attacking barrier
			animation.play("run")
	
	# Barrier exited
	elif body == target_barrier or (body.get_parent() and body.get_parent() == target_barrier):
		target_barrier = null
		move_speed = original_speed
		
		# Stop barrier attack timer
		var barrier_timer = get_node_or_null("BarrierAttackTimer")
		if barrier_timer:
			barrier_timer.stop()
			barrier_timer.queue_free()
		
		if animation and target_hero == null:  # Only switch to run if not attacking hero
			animation.play("run")

# Set pause state
func set_paused(paused: bool):
	is_paused = paused
	
	# Store velocity when pausing, restore when unpausing
	if is_paused:
		velocity = Vector2.ZERO
		
		# Pause timers
		if slow_timer:
			slow_timer.paused = true
		if attack_hero_timer:
			attack_hero_timer.paused = true
		if attack_base_timer:
			attack_base_timer.paused = true
		
		var barrier_timer = get_node_or_null("BarrierAttackTimer")
		if barrier_timer:
			barrier_timer.paused = true
		
		# Pause animations
		if animation:
			animation.pause()
		
		# Find and pause all animation players in children
		_pause_all_animations(self, true)
	else:
		# Resume timers
		if slow_timer:
			slow_timer.paused = false
		if attack_hero_timer:
			attack_hero_timer.paused = false
		if attack_base_timer:
			attack_base_timer.paused = false
		
		var barrier_timer = get_node_or_null("BarrierAttackTimer")
		if barrier_timer:
			barrier_timer.paused = false
		
		# Resume animations
		if animation:
			animation.play()
		
		# Find and resume all animation players in children
		_pause_all_animations(self, false)
	
	print("Enemy8: Pause state set to " + str(paused))

# Helper function to recursively pause/unpause all animations in a node and its children
func _pause_all_animations(node: Node, should_pause: bool):
	if node is AnimationPlayer:
		if should_pause:
			node.pause()
		else:
			node.play()
	elif node is AnimatedSprite2D:
		if should_pause:
			node.pause()
		else:
			node.play()
	
	# Recursively process all children
	for child in node.get_children():
		_pause_all_animations(child, should_pause)

# Apply knockback (for compatibility with effects)
func apply_knockback(direction: Vector2, strength: float):
	# Skip if dying or paused
	if is_dying or is_paused:
		return
	
	print("Enemy8: Applying knockback with strength " + str(strength))
	
	# Apply impulse in the given direction
	velocity += direction * strength

# Add this function to handle when a barrier is destroyed
func _on_barrier_destroyed(barrier):
	if barrier == target_barrier:
		print("Enemy8: Current target barrier was destroyed")
		target_barrier = null
		move_speed = original_speed
		
		# Stop barrier attack timer
		var barrier_timer = get_node_or_null("BarrierAttackTimer")
		if barrier_timer:
			barrier_timer.stop()
			barrier_timer.queue_free()
		
		if animation and target_hero == null:  # Only switch to run if not attacking hero
			animation.play("run")
