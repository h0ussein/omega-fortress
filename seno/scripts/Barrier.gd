extends StaticBody2D

# Barrier properties
@export var max_health: float = 500.0
var health: float = max_health
var grid_position = Vector2i(0, 0)
var is_dying: bool = false

# Visual feedback
var health_bar: ProgressBar
var flash_tween: Tween

# References
var grid_system
var barrier_manager

signal barrier_destroyed(barrier, grid_pos)

func _ready():
	# Make sure the barrier is visible
	visible = true
	
	# Set a higher z-index to ensure barriers appear above the grid
	z_index = 10
	
	# Add to barriers group for targeting
	add_to_group("barriers")
	
	# Find references
	grid_system = get_node_or_null("/root/Node2D_main/GridSystem")
	barrier_manager = get_node_or_null("/root/Node2D_main/BarrierPlacer")
	
	# Create health bar
	create_health_bar()
	
	print("Barrier initialized at grid position: ", grid_position, " with health: ", health)

func create_health_bar():
	# Create a ProgressBar node for the health bar
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	
	# Set size and position
	health_bar.custom_minimum_size = Vector2(30, 5)
	health_bar.position = Vector2(-15, -25)  # Position above the barrier
	
	# Set up the health bar properties
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.show_percentage = false
	
	# Style the health bar
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.8, 0.2)  # Green
	style_box.corner_radius_top_left = 1
	style_box.corner_radius_top_right = 1
	style_box.corner_radius_bottom_right = 1
	style_box.corner_radius_bottom_left = 1
	health_bar.add_theme_stylebox_override("fill", style_box)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray background
	bg_style.corner_radius_top_left = 1
	bg_style.corner_radius_top_right = 1
	bg_style.corner_radius_bottom_right = 1
	bg_style.corner_radius_bottom_left = 1
	health_bar.add_theme_stylebox_override("background", bg_style)
	
	# Initially hide the health bar, only show when damaged
	health_bar.visible = false
	
	# Add the health bar to the barrier
	add_child(health_bar)

func take_damage(amount: float):
	# Skip if already dying
	if is_dying:
		return
		
	# Apply damage
	health -= amount
	
	# Show health bar when damaged
	health_bar.visible = true
	
	# Update health bar
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
	
	print("Barrier at ", grid_position, " took ", amount, " damage. Health: ", health, "/", max_health)
	
	# Check if destroyed
	if health <= 0:
		destroy()

func flash_damage():
	# Cancel previous tween if exists
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()
	
	# Flash red when taking damage
	modulate = Color(1.5, 0.5, 0.5)  # Red tint
	
	# Create a tween to restore normal color
	flash_tween = create_tween()
	flash_tween.tween_property(self, "modulate", Color(1, 1, 1), 0.3)

func destroy():
	if is_dying:
		return  # Prevent multiple destroy calls
		
	is_dying = true
	print("Barrier at ", grid_position, " destroyed!")
	
	# Emit signal before removing from grid
	emit_signal("barrier_destroyed", self, grid_position)
	
	# Remove from grid system
	if grid_system and grid_system.has_method("set_cell_empty"):
		grid_system.set_cell_empty(grid_position)
		grid_system.grid_cells[str(grid_position)] = 0  # Ensure it's marked as empty
		grid_system.grid_changed = true  # Mark grid as changed
		grid_system.path_cache.clear()  # Clear path cache
		grid_system.emit_signal("grid_updated")
		grid_system.queue_redraw()
	
	# Create destruction effect
	show_destruction_effect()
	
	# Remove from barrier manager's list (will be handled by the signal)
	# The barrier manager will handle this in its _on_barrier_destroyed method

func show_destruction_effect():
	# Hide the health bar
	if health_bar:
		health_bar.visible = false
	
	# Create destruction particles
	var particles = CPUParticles2D.new()
	particles.name = "DestructionParticles"
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = 15
	particles.lifetime = 0.8
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.gravity = Vector2(0, 98)
	particles.initial_velocity_min = 20
	particles.initial_velocity_max = 50
	particles.scale_amount_min = 2
	particles.scale_amount_max = 4
	particles.color = Color(0.7, 0.7, 0.7)  # Gray color for barrier debris
	add_child(particles)
	
	# Fade out the barrier
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(queue_free)

# For debugging
func get_health_percentage():
	return health / max_health
