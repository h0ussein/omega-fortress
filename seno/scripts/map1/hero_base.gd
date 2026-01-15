extends CharacterBody2D

# Signals
signal selected(hero)
signal hero_killed(hero)

# Hero properties (to be overridden by child classes)
var hero_type = "base"
var description = "Basic hero unit"
var attack_range = 100.0
var attack_speed = 1.0
var health = 100
var move_speed = 100.0
var base_cost = 100

# References
var grid_system = null
var grid_position = Vector2i(0, 0)

# Movement
var move_target = null
var path = []
var current_path_index = 0

# Selection
var is_selected = false
@onready var selection_indicator = $SelectionIndicator if has_node("SelectionIndicator") else null
@onready var selection_panel = $SelectionPanel if has_node("SelectionPanel") else null

func _ready():
	# Initialize selection UI (hidden by default)
	if selection_indicator:
		selection_indicator.visible = false
	
	if selection_panel:
		selection_panel.visible = false
		
		# Connect button signals if they exist
		var move_button = selection_panel.get_node_or_null("MoveButton")
		if move_button:
			move_button.pressed.connect(_on_move_button_pressed)
		
		var attack_button = selection_panel.get_node_or_null("AttackButton")
		if attack_button:
			attack_button.pressed.connect(_on_attack_button_pressed)
		
		print("Hero: Found existing SelectionPanel")
	else:
		print("Hero: No SelectionPanel found")
	
	# Make sure we're input_pickable
	input_pickable = true
	
	print("Hero: Initializing " + hero_type)
	
	# Set up attack timer if it exists
	var attack_timer = get_node_or_null("AttackTimer")
	if attack_timer:
		attack_timer.wait_time = 1.0 / attack_speed
		print("Hero: Set up attack timer with interval: " + str(attack_timer.wait_time) + "s")
	
	# Connect area signals for detecting enemies if they exist
	var area = get_node_or_null("Area2D")
	if area:
		if area.has_signal("body_entered"):
			area.body_entered.connect(_on_body_entered)
		if area.has_signal("body_exited"):
			area.body_exited.connect(_on_body_exited)
		print("Hero: Connected area signals")
	
	print("Hero: Ready!")

func _process(delta):
	# Handle movement along path
	if path.size() > 0 and current_path_index < path.size():
		var target_pos = path[current_path_index]
		var direction = (target_pos - position).normalized()
		velocity = direction * move_speed
		
		# If we're close enough to the current waypoint, move to the next one
		if position.distance_to(target_pos) < 5:
			current_path_index += 1
			
			# If we've reached the end of the path, update our grid position
			if current_path_index >= path.size():
				path = []
				velocity = Vector2.ZERO
				if grid_system:
					grid_position = grid_system.world_to_grid(position)
					grid_system.update_hero_position(self, grid_position)
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("selected", self)
		print("Hero: Selected via input_event")

func set_selected(selected):
	is_selected = selected
	
	# Show/hide the selection indicator
	if selection_indicator:
		selection_indicator.visible = selected
	
	# Show/hide the selection panel
	if selection_panel:
		selection_panel.visible = selected
	
	# You can also add visual indication for selection
	# For example, change the modulate color or show a selection sprite
	if selected:
		modulate = Color(1.2, 1.2, 1.2)  # Slightly brighter
	else:
		modulate = Color(1, 1, 1)  # Normal
	
	print("Hero: Selection state changed to " + str(selected))

func set_move_target(target_position):
	move_target = target_position
	
	# Get path from current position to target
	if grid_system:
		var start_grid_pos = grid_system.world_to_grid(position)
		var end_grid_pos = grid_system.world_to_grid(target_position)
		
		path = grid_system.find_path(start_grid_pos, end_grid_pos)
		
		# Convert grid positions to world positions
		for i in range(path.size()):
			path[i] = grid_system.grid_to_world(path[i])
		
		current_path_index = 0
		
		print("Hero: Path found with " + str(path.size()) + " points")
	else:
		print("ERROR: grid_system not set")

func _on_move_button_pressed():
	# Tell the HeroManager we want to move this hero
	var hero_manager = get_node("/root/GameMap/HeroManager")
	if hero_manager:
		hero_manager.start_move_mode_for_hero(self)
		print("Hero: Move button pressed")
	else:
		print("ERROR: HeroManager not found")

func _on_attack_button_pressed():
	# Handle attack button press
	print("Hero: Attack button pressed")
	# Implement attack logic here

func _on_body_entered(body):
	# Handle enemy entering attack range
	if body.is_in_group("enemies"):
		print("Hero: Enemy entered attack range")
		# Start attacking

func _on_body_exited(body):
	# Handle enemy exiting attack range
	if body.is_in_group("enemies"):
		print("Hero: Enemy exited attack range")
		# Stop attacking if no other enemies in range

func get_sell_value():
	return base_cost * 0.7  # Return 70% of the base cost

func die():
	emit_signal("hero_killed", self)
	queue_free()
