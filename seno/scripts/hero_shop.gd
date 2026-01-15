extends Control

signal hero_purchase_requested(hero_type, position)

# Update the hero_types dictionary to include the fighter
var hero_types = {
	"mage": {
		"cost": 100,
		"scene": "res://scenes/heros/fire_wizard.tscn"
	},
	"fighter": {
		"cost": 250,
		"scene": "res://scenes/heros/fighter.tscn"
	},
	"ice": {
		"cost": 75,
		"scene": "res://scenes/heros/ice_wizard.tscn"
	},
	"electric": {
		"cost": 300,
		"scene": "res://scenes/heros/electric_wizard.tscn"
	},
	"laser": {
		"cost": 600,
		"scene": "res://scenes/heros/laser_wizard.tscn"
	},
	"purple": {
		"cost": 200,
		"scene": "res://scenes/heros/purple_wizard.tscn"
	},
	"healer": {
		"cost": 300,
		"scene": "res://scenes/heros/healer_wizard.tscn"
	}
}

# Currently dragged hero
var dragging_hero = false
var drag_hero_type = ""
var drag_start_position = Vector2()
var drag_preview = null
var hero_limit_reached = false  # New variable to track hero limit

func _ready():
	print("HeroShop: Ready")

	# Set up anchoring to bottom center
	setup_anchoring()

	# Connect all MageButtons in the Panel
	var panel = get_node_or_null("Panel")
	if panel:
		# Connect MageButton (original mage)
		var mage_button = panel.get_node_or_null("MageButton")
		if mage_button:
			print("HeroShop: Found MageButton")
			if mage_button.gui_input.is_connected(_on_hero_button_input.bind("mage")):
				mage_button.gui_input.disconnect(_on_hero_button_input.bind("mage"))
			mage_button.gui_input.connect(_on_hero_button_input.bind("mage"))
			_add_cost_label(mage_button, "mage")
		
		# Connect MageButton2 (fighter)
		var fighter_button = panel.get_node_or_null("MageButton2")
		if fighter_button:
			print("HeroShop: Found MageButton2 (fighter)")
			if fighter_button.gui_input.is_connected(_on_hero_button_input.bind("fighter")):
				fighter_button.gui_input.disconnect(_on_hero_button_input.bind("fighter"))
			fighter_button.gui_input.connect(_on_hero_button_input.bind("fighter"))
			_add_cost_label(fighter_button, "fighter")
		
		# Connect MageButton3 (ice)
		var ice_button = panel.get_node_or_null("MageButton3")
		if ice_button:
			print("HeroShop: Found MageButton3 (ice)")
			if ice_button.gui_input.is_connected(_on_hero_button_input.bind("ice")):
				ice_button.gui_input.disconnect(_on_hero_button_input.bind("ice"))
			ice_button.gui_input.connect(_on_hero_button_input.bind("ice"))
			_add_cost_label(ice_button, "ice")
		
		# Connect MageButton4 (electric)
		var electric_button = panel.get_node_or_null("MageButton4")
		if electric_button:
			print("HeroShop: Found MageButton4 (electric)")
			if electric_button.gui_input.is_connected(_on_hero_button_input.bind("electric")):
				electric_button.gui_input.disconnect(_on_hero_button_input.bind("electric"))
			electric_button.gui_input.connect(_on_hero_button_input.bind("electric"))
			_add_cost_label(electric_button, "electric")
		
		# Connect MageButton5 (laser)
		var laser = panel.get_node_or_null("MageButton5")
		if laser:
			print("HeroShop: Found MageButton5 (laser)")
			if laser.gui_input.is_connected(_on_hero_button_input.bind("laser")):
				laser.gui_input.disconnect(_on_hero_button_input.bind("laser"))
			laser.gui_input.connect(_on_hero_button_input.bind("laser"))
			_add_cost_label(laser, "laser")
		
		# Connect MageButton6 (tank)
		var purple = panel.get_node_or_null("MageButton6")
		if purple:
			print("HeroShop: Found MageButton6 (purple)")
			if purple.gui_input.is_connected(_on_hero_button_input.bind("purple")):
				purple.gui_input.disconnect(_on_hero_button_input.bind("purple"))
			purple.gui_input.connect(_on_hero_button_input.bind("purple"))
			_add_cost_label(purple, "purple")
		
		# Connect MageButton7 (healer)
		var healer_button = panel.get_node_or_null("MageButton7")
		if healer_button:
			print("HeroShop: Found MageButton7 (healer)")
			if healer_button.gui_input.is_connected(_on_hero_button_input.bind("healer")):
				healer_button.gui_input.disconnect(_on_hero_button_input.bind("healer"))
			healer_button.gui_input.connect(_on_hero_button_input.bind("healer"))
			_add_cost_label(healer_button, "healer")
	else:
		print("HeroShop: ERROR - Panel not found")

# Helper function to add cost label to a button
func _add_cost_label(button, hero_type):
	if not button.has_node("CostLabel") and hero_types.has(hero_type):
		var cost_label = Label.new()
		cost_label.name = "CostLabel"
		cost_label.text = str(hero_types[hero_type]["cost"]) + " gold"
		cost_label.position = Vector2(5, button.size.y - 20)
		button.add_child(cost_label)

func _map_button_to_hero_type(button_name: String) -> String:
	# Map MageButton to "mage", MageButton2 to "ice", etc.
	match button_name:
		"MageButton": return "mage"
		"MageButton2": return "fighter"
		"MageButton3": return "ice"
		"MageButton4": return "electric"
		"MageButton5": return "laser"
		"MageButton6": return "purple"
		"MageButton7": return "healer"
		_: return "mage"  # Default to mage if unknown

# Set up proper anchoring to keep the shop fixed on screen
func setup_anchoring():
	# Get the panel
	var panel = get_node_or_null("Panel")
	if not panel:
		print("HeroShop: Panel not found, cannot set up anchoring")
		return

	# Set anchors to center horizontally at bottom
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0

	# Set offsets to position from bottom center
	offset_left = -panel.size.x / 2
	offset_right = panel.size.x / 2
	offset_top = -panel.size.y - 10
	offset_bottom = -10

	print("HeroShop: Set up anchoring to bottom center")

func _on_hero_button_input(event, hero_type):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Skip if hero limit reached
			if hero_limit_reached:
				print("HeroShop: Hero limit reached, cannot purchase more heroes")
				return
				
			if event.pressed:
				print("HeroShop: Button pressed for " + hero_type)
				# Start dragging
				drag_hero_type = hero_type
				drag_start_position = get_global_mouse_position()
				_create_drag_preview(hero_type)
			elif dragging_hero:
				print("HeroShop: Button released for " + hero_type)
				# Drop the hero
				var drop_position = get_global_mouse_position()
				_try_purchase_hero(hero_type, drop_position)
				_remove_drag_preview()

func _process(delta):
	if dragging_hero and drag_preview:
		# Update drag preview position to follow the mouse exactly
		drag_preview.global_position = get_global_mouse_position() - drag_preview.size / 2

func _create_drag_preview(hero_type):
	print("HeroShop: Creating drag preview for " + hero_type)
	
	# Create a visual preview of the hero being dragged
	drag_preview = TextureRect.new()

	# Use the correct path from debug output
	var texture_path = "res://assets/heroes/mage_icon.png"

	var texture = null
	if ResourceLoader.exists(texture_path):
		texture = load(texture_path)
		print("Found hero icon at: " + texture_path)

	if texture:
		drag_preview.texture = texture
	else:
		# Fallback to a colored rect if texture not found
		print("Hero icon not found, using fallback colored rect")
		drag_preview = ColorRect.new()
		drag_preview.color = Color(0.5, 0.5, 1.0, 0.7)

	# Make the preview smaller - 40x40 pixels
	drag_preview.custom_minimum_size = Vector2(40, 40)
	drag_preview.size = Vector2(40, 40)
	drag_preview.expand = true
	drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Center exactly on mouse position
	drag_preview.global_position = get_global_mouse_position() - drag_preview.size / 2
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Add to the UI layer
	get_tree().root.add_child(drag_preview)
	dragging_hero = true
	
	print("HeroShop: Drag preview created")

func _remove_drag_preview():
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	dragging_hero = false
	drag_hero_type = ""
	
	print("HeroShop: Drag preview removed")

func _try_purchase_hero(hero_type, position):
	print("Attempting to purchase hero: " + hero_type + " at position: " + str(position))

	# Check if we have enough gold
	var main_scene = get_node_or_null("/root/Node2D_main")
	if main_scene and hero_types.has(hero_type):
		var cost = hero_types[hero_type]["cost"]
		if main_scene.gold < cost:
			print("HeroShop: Not enough gold to purchase hero")
			return
		
		# Check if hero limit reached
		if hero_limit_reached:
			print("HeroShop: Hero limit reached, cannot purchase more heroes")
			return
	
	# Emit signal to let the main scene handle the purchase
	print("Emitting hero_purchase_requested signal")
	emit_signal("hero_purchase_requested", hero_type, position)

# Called from main scene to update button states based on available gold and hero limit
func update_button_states(available_gold, limit_reached = false):
	var panel = get_node_or_null("Panel")
	if not panel:
		return
	
	# Update hero limit status
	hero_limit_reached = limit_reached
	
	# Add a hero limit label if it doesn't exist
	if hero_limit_reached and not panel.has_node("HeroLimitLabel"):
		var limit_label = Label.new()
		limit_label.name = "HeroLimitLabel"
		limit_label.text = "HERO LIMIT REACHED (10/10)"
		limit_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Red color
		limit_label.position = Vector2(panel.size.x / 2 - 100, 10)
		limit_label.size = Vector2(200, 20)
		limit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(limit_label)
	elif not hero_limit_reached and panel.has_node("HeroLimitLabel"):
		panel.get_node("HeroLimitLabel").queue_free()
		
	# Update MageButton (mage)
	_update_button_state(panel.get_node_or_null("MageButton"), "mage", available_gold)
	
	# Update MageButton2 (fighter)
	_update_button_state(panel.get_node_or_null("MageButton2"), "fighter", available_gold)
	
	# Update MageButton3 (ice)
	_update_button_state(panel.get_node_or_null("MageButton3"), "ice", available_gold)
	
	# Update MageButton4 (electric)
	_update_button_state(panel.get_node_or_null("MageButton4"), "electric", available_gold)
	
	# Update MageButton5 (archer)
	_update_button_state(panel.get_node_or_null("MageButton5"), "laser", available_gold)
	
	# Update MageButton6 (tank)
	_update_button_state(panel.get_node_or_null("MageButton6"), "purple", available_gold)
	
	# Update MageButton7 (healer)
	_update_button_state(panel.get_node_or_null("MageButton7"), "healer", available_gold)

# Helper function to update a button's state
func _update_button_state(button, hero_type, available_gold):
	if button and hero_types.has(hero_type):
		var cost = hero_types[hero_type]["cost"]
		
		# Disable if not enough gold OR hero limit reached
		button.disabled = cost > available_gold or hero_limit_reached
		
		# Visual feedback
		if cost > available_gold:
			button.modulate = Color(0.5, 0.5, 0.5)  # Gray out if not enough gold
		elif hero_limit_reached:
			button.modulate = Color(0.5, 0.3, 0.3)  # Red tint if hero limit reached
		else:
			button.modulate = Color(1, 1, 1)  # Normal color if can purchase

# Helper function to get hero data
func get_hero_data(hero_type: String) -> Dictionary:
	if hero_types.has(hero_type):
		return hero_types[hero_type]
	else:
		print("HeroShop: ERROR - Hero type not found: " + hero_type)
		return {
			"cost": 200,
			"scene": "res://scenes/red_wizard_woman.tscn"
		}

# Function to update hero shop availability based on hero limit
func update_availability(available: bool):
	var panel = get_node_or_null("Panel")
	if not panel:
		return
	
	# Update hero limit status
	hero_limit_reached = !available
	
	# Add a hero limit label if it doesn't exist
	if hero_limit_reached and not panel.has_node("HeroLimitLabel"):
		var limit_label = Label.new()
		limit_label.name = "HeroLimitLabel"
		limit_label.text = "HERO LIMIT REACHED (10/10)"
		limit_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Red color
		limit_label.position = Vector2(panel.size.x / 2 - 100, 10)
		limit_label.size = Vector2(200, 20)
		limit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(limit_label)
	elif not hero_limit_reached and panel.has_node("HeroLimitLabel"):
		panel.get_node("HeroLimitLabel").queue_free()
	
	# Update button states based on availability
	var main_scene = get_node_or_null("/root/Node2D_main")
	var available_gold = 0
	if main_scene:
		available_gold = main_scene.gold
	
	# Update all buttons
	for i in range(1, 8):
		var button_name = "MageButton" if i == 1 else "MageButton" + str(i)
		var button = panel.get_node_or_null(button_name)
		if button:
			var hero_type = _map_button_to_hero_type(button_name)
			if hero_types.has(hero_type):
				var cost = hero_types[hero_type]["cost"]
				
				# Disable if not enough gold OR hero limit reached
				button.disabled = cost > available_gold or hero_limit_reached
				
				# Visual feedback
				if cost > available_gold:
					button.modulate = Color(0.5, 0.5, 0.5)  # Gray out if not enough gold
				elif hero_limit_reached:
					button.modulate = Color(0.5, 0.3, 0.3)  # Red tint if hero limit reached
				else:
					button.modulate = Color(1, 1, 1)  # Normal color if can purchase
