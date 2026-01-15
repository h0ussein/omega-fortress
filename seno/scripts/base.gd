extends Node2D

@export var max_health: float = 100.0
var health: float = 100.0
var is_destroyed: bool = false  # Add this flag
var health_bar: ProgressBar
var health_label: Label
@onready var main = $".."
func _ready():
	health = max_health
	add_to_group("base")
	
	# Create health bar
	create_health_bar()
	
	print("Base: Ready with " + str(health) + " health")

func create_health_bar():
	# Create a Control node to contain the health bar
	var health_container = Control.new()
	health_container.name = "HealthContainer"
	health_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	health_container.position = Vector2(0, -50)  # Position above the base
	add_child(health_container)
	
	# Create background panel
	var panel = Panel.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(120, 30)
	panel.size = Vector2(120, 30)
	panel.position = Vector2(-60, 0)  # Center horizontally
	health_container.add_child(panel)
	
	# Create health bar
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.custom_minimum_size = Vector2(100, 20)
	health_bar.size = Vector2(100, 20)
	health_bar.position = Vector2(-50, 5)  # Center in panel
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.show_percentage = false
	
	# Style the health bar
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.8, 0.2)  # Green
	style_box.corner_radius_top_left = 3
	style_box.corner_radius_top_right = 3
	style_box.corner_radius_bottom_right = 3
	style_box.corner_radius_bottom_left = 3
	health_bar.add_theme_stylebox_override("fill", style_box)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray background
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_right = 3
	bg_style.corner_radius_bottom_left = 3
	health_bar.add_theme_stylebox_override("background", bg_style)
	
	health_container.add_child(health_bar)
	
	# Create health label
	health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.text = str(int(health)) + "/" + str(int(max_health))
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_label.custom_minimum_size = Vector2(100, 20)
	health_label.size = Vector2(100, 20)
	health_label.position = Vector2(-50, 5)  # Same position as health bar
	
	# Add outline to make text more readable
	health_label.add_theme_color_override("font_color", Color(1, 1, 1))  # White text
	health_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))  # Black outline
	health_label.add_theme_constant_override("outline_size", 1)
	
	health_container.add_child(health_label)
	
	# Add title label
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "BASE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size = Vector2(100, 20)
	title_label.size = Vector2(100, 20)
	title_label.position = Vector2(-50, -20)  # Above health bar
	
	# Style the title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(1, 0.8, 0))  # Gold color
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))  # Black outline
	title_label.add_theme_constant_override("outline_size", 2)
	
	health_container.add_child(title_label)
	
	print("Base: Created health bar")

func take_damage_base(amount: float):
	if is_destroyed:  # Skip if already destroyed
		main.game_over()
	
	print("Base: Taking " + str(amount) + " damage")
	health -= amount
	
	# Update health bar
	if health_bar:
		health_bar.value = health
		
		# Change color based on health percentage
		var health_percent = health / max_health
		var style_box = health_bar.get_theme_stylebox("fill", "")
		
		if style_box is StyleBoxFlat:
			if health_percent > 0.6:
				style_box.bg_color = Color(0.2, 0.8, 0.2)  # Green
			elif health_percent > 0.3:
				style_box.bg_color = Color(0.9, 0.7, 0.1)  # Yellow/Orange
			else:
				style_box.bg_color = Color(0.9, 0.2, 0.2)  # Red
	
	# Update health label
	if health_label:
		health_label.text = str(int(health)) + "/" + str(int(max_health))
	
	if health <= 0 and not is_destroyed:
		is_destroyed = true  # Set the flag
		print("Base destroyed! Game Over!")
		
		# Show game over screen or perform other game over actions
		var main_scene = get_node_or_null("/root/Node2D_main")
		if main_scene and main_scene.has_method("game_over"):
			main_scene.game_over()
		
		# Visual feedback for destruction
		show_destruction_effect()

func show_destruction_effect():
	# Create explosion particles
	var particles = CPUParticles2D.new()
	particles.name = "DestructionParticles"
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = 50
	particles.lifetime = 2.0
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.gravity = Vector2(0, 98)
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 200
	particles.scale_amount_min = 2
	particles.scale_amount_max = 5
	particles.color = Color(1, 0.5, 0)  # Orange/fire color
	add_child(particles)
	
	# Fade out the base
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0.3), 1.0)
	
	# Hide the health bar
	if health_bar and health_bar.get_parent():
		health_bar.get_parent().visible = false
	
	print("Base: Showing destruction effect")
