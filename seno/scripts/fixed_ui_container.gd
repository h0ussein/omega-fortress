extends CanvasLayer

# Signals to relay from UI elements
signal hero_purchase_requested(hero_type, position)
signal move_button_pressed(hero)
signal sell_button_pressed(hero)
signal barrier_button_pressed
signal pause_toggled(is_paused)

# References to UI components
var gold_display
var wave_display
var hero_panel
var pause_button
var zoom_controls
var hero_shop
var barrier_button

# Main scene reference for getting game state
var main_scene
var current_gold = 0  # Track gold locally as a fallback
var is_game_paused = false
var heroes_paused = false

# Track the currently selected hero for panel positioning
var tracked_hero = null

# Camera controller reference
var camera_controller = null

func _ready():
	# Set this node to always process even when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Set a high layer to ensure UI is on top
	layer = 10
	
	# Find main scene
	main_scene = get_node_or_null("/root/Node2D_main")
	if main_scene:
		print("FixedUIContainer: Found main scene")
		# Initialize current_gold from main scene
		if main_scene.get("gold") != null:
			current_gold = main_scene.gold
	else:
		print("FixedUIContainer: WARNING - Main scene not found")
	
	# Find camera controller
	find_camera_controller()
	
	# Create UI components
	create_gold_display()
	create_wave_display()
	create_hero_panel()
	create_pause_button()
	create_zoom_controls()
	create_barrier_button()
	
	# Find and integrate existing hero shop
	find_hero_shop()
	
	# Connect signals to main scene
	connect_signals_to_main()
	
	print("FixedUIContainer: Ready")
	
	# Debug print to check if UI elements are visible
	print("FixedUIContainer: Gold display visible: " + str(gold_display.visible if gold_display else "null"))
	print("FixedUIContainer: Wave display visible: " + str(wave_display.visible if wave_display else "null"))
	print("FixedUIContainer: Pause button visible: " + str(pause_button.visible if pause_button else "null"))

func _process(delta):
	# Update gold display if main scene exists
	if main_scene and main_scene.get("gold") != null:
		# Check if gold amount has changed
		if current_gold != main_scene.gold:
			current_gold = main_scene.gold
			update_gold_display()
	
	# Update hero panel position if tracking a hero
	if tracked_hero and is_instance_valid(tracked_hero) and hero_panel and hero_panel.visible:
		update_hero_panel_position()
	elif tracked_hero and !is_instance_valid(tracked_hero):
		# Hero is no longer valid, hide the panel
		if hero_panel:
			hide_hero_panel()
		tracked_hero = null
		print("FixedUIContainer: Tracked hero is no longer valid, hiding panel")

# Find camera controller
func find_camera_controller():
	# Try to find the camera controller
	var camera = get_viewport().get_camera_2d()
	if camera:
		print("FixedUIContainer: Found camera at " + str(camera.get_path()))
		
		# Check if camera has the CameraController script
		if camera.get_script() and camera.get_script().resource_path.ends_with("CameraController.gd"):
			camera_controller = camera
			print("FixedUIContainer: Found camera controller")
		else:
			print("FixedUIContainer: Camera does not have CameraController script")
	else:
		print("FixedUIContainer: WARNING - Could not find camera")

# Connect signals to main scene
func connect_signals_to_main():
	if not main_scene:
		return
		
	# Connect our signals to main scene methods
	if has_signal("hero_purchase_requested") and main_scene.has_method("_on_hero_purchase_requested"):
		if not hero_purchase_requested.is_connected(main_scene._on_hero_purchase_requested):
			hero_purchase_requested.connect(main_scene._on_hero_purchase_requested)
			print("FixedUIContainer: Connected hero_purchase_requested signal")
	
	if has_signal("move_button_pressed") and main_scene.has_method("_on_move_button_pressed"):
		if not move_button_pressed.is_connected(main_scene._on_move_button_pressed):
			move_button_pressed.connect(main_scene._on_move_button_pressed)
			print("FixedUIContainer: Connected move_button_pressed signal")
	
	if has_signal("sell_button_pressed") and main_scene.has_method("_on_sell_button_pressed"):
		if not sell_button_pressed.is_connected(main_scene._on_sell_button_pressed):
			sell_button_pressed.connect(main_scene._on_sell_button_pressed)
			print("FixedUIContainer: Connected sell_button_pressed signal")
	
	if has_signal("barrier_button_pressed") and main_scene.has_method("_on_barrier_button_pressed"):
		if not barrier_button_pressed.is_connected(main_scene._on_barrier_button_pressed):
			barrier_button_pressed.connect(main_scene._on_barrier_button_pressed)
			print("FixedUIContainer: Connected barrier_button_pressed signal")
	
	if has_signal("pause_toggled") and main_scene.has_method("_on_pause_button_toggled"):
		if not pause_toggled.is_connected(main_scene._on_pause_button_toggled):
			pause_toggled.connect(main_scene._on_pause_button_toggled)
			print("FixedUIContainer: Connected pause_toggled signal")

# Create gold display
func create_gold_display():
	# Check if gold display already exists
	gold_display = get_node_or_null("/root/Node2D_main/FixedUIContainer/Control2/GoldDisplay")
	if gold_display:
		print("FixedUIContainer: Found existing GoldDisplay")
		return
		
	# Create a Control container for the gold display that will handle anchoring
	var gold_container = Control.new()
	gold_container.name = "GoldDisplayContainer"
	gold_container.anchor_right = 1.0  # Stretch to fill width
	gold_container.anchor_bottom = 0.0  # Stick to top
	gold_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Pass mouse events through
	add_child(gold_container)
	
	# Create gold display
	gold_display = Control.new()
	gold_display.name = "GoldDisplay"
	
	# Set up anchoring to left side
	gold_display.anchor_left = 0.0
	gold_display.anchor_right = 0.0
	gold_display.anchor_top = 0.0
	gold_display.anchor_bottom = 0.0
	
	# Set position relative to anchor (left edge)
	gold_display.offset_left = 10
	gold_display.offset_top = 10
	gold_display.offset_right = 160
	gold_display.offset_bottom = 50
	
	# Set size
	gold_display.custom_minimum_size = Vector2(150, 40)
	
	var background = Panel.new()
	background.name = "Background"
	# Make background fill the entire control
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.offset_left = 0
	background.offset_top = 0
	background.offset_right = 0
	background.offset_bottom = 0
	# Add a visible style to the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray, semi-transparent
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	background.add_theme_stylebox_override("panel", style)
	gold_display.add_child(background)
	print("FixedUIContainer: Added background panel to gold display")
	
	var gold_label = Label.new()
	gold_label.name = "GoldLabel"
	# Make label fill the control but with some padding
	gold_label.anchor_right = 1.0
	gold_label.anchor_bottom = 1.0
	gold_label.offset_left = 10
	gold_label.offset_top = 5
	gold_label.offset_right = -10
	gold_label.offset_bottom = -5
	gold_label.text = str(current_gold)
	# Explicitly set horizontal alignment to left
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_display.add_child(gold_label)
	
	# Add script to gold display
	var script = GDScript.new()
	script.source_code = """
extends Control

@onready var gold_label = $GoldLabel
var current_gold = 0

func _ready():
	# Initialize with zero gold
	update_gold(0)
	
	print("GoldDisplay: Ready")

func update_gold(amount: int):
	current_gold = amount
	if gold_label:
		gold_label.text = str(amount)
	
	print("GoldDisplay: Updated to " + str(amount) + " gold")

func get_current_gold() -> int:
	return current_gold
"""
	script.reload()
	gold_display.set_script(script)
	
	gold_container.add_child(gold_display)
	print("FixedUIContainer: Created gold display with proper anchoring")
	
	# Initialize gold display
	update_gold_display()
	
	# Ensure the gold display is visible
	gold_display.visible = true
	print("FixedUIContainer: Gold display visibility set to true")

# Create wave display
func create_wave_display():
	# Check if wave display already exists
	wave_display = get_node_or_null("/root/Node2D_main/FixedUIContainer/Control2/WaveDisplay")
	if wave_display:
		print("FixedUIContainer: Found existing WaveDisplay")
		return
		
	# Create a Control container for the wave display that will handle anchoring
	var wave_container = Control.new()
	wave_container.name = "WaveDisplayContainer"
	wave_container.anchor_right = 1.0  # Stretch to fill width
	wave_container.anchor_bottom = 0.0  # Stick to top
	wave_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Pass mouse events through
	add_child(wave_container)
	
	# Create wave display
	wave_display = Control.new()
	wave_display.name = "WaveDisplay"
	
	# Set up anchoring to center top
	wave_display.anchor_left = 0.5
	wave_display.anchor_right = 0.5
	wave_display.anchor_top = 0.0
	wave_display.anchor_bottom = 0.0
	
	# Set position relative to anchor (center top)
	wave_display.offset_left = -100
	wave_display.offset_top = 10
	wave_display.offset_right = 100
	wave_display.offset_bottom = 70
	
	# Set size
	wave_display.custom_minimum_size = Vector2(200, 60)
	
	var background = Panel.new()
	background.name = "Background"
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	# Add a visible style to the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray, semi-transparent
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	background.add_theme_stylebox_override("panel", style)
	wave_display.add_child(background)
	print("FixedUIContainer: Added background panel to wave display")
	
	var wave_label = Label.new()
	wave_label.name = "WaveLabel"
	wave_label.anchor_right = 1.0
	wave_label.anchor_bottom = 0.5
	wave_label.text = "Wave: 1 / 5"
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_display.add_child(wave_label)
	
	var countdown_label = Label.new()
	countdown_label.name = "CountdownLabel"
	countdown_label.anchor_top = 0.5
	countdown_label.anchor_right = 1.0
	countdown_label.anchor_bottom = 1.0
	countdown_label.text = "Next wave in: 10s"
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_display.add_child(countdown_label)
	
	var next_wave_button = Button.new()
	next_wave_button.name = "NextWaveButton"
	next_wave_button.anchor_left = 0.5
	next_wave_button.anchor_right = 0.5
	next_wave_button.anchor_top = 1.0
	next_wave_button.anchor_bottom = 1.0
	next_wave_button.offset_left = -50
	next_wave_button.offset_top = 5
	next_wave_button.offset_right = 50
	next_wave_button.offset_bottom = 35
	next_wave_button.text = "Start Wave"
	next_wave_button.pressed.connect(_on_next_wave_button_pressed)
	wave_display.add_child(next_wave_button)
	
	# Add script to wave display
	var script = load("res://scripts/ui/wave_display.gd")
	if script:
		wave_display.set_script(script)
	else:
		# Create fallback script
		script = GDScript.new()
		script.source_code = """
extends Control

@onready var wave_label = $WaveLabel
@onready var countdown_label = $CountdownLabel
@onready var next_wave_button = $NextWaveButton

var wave_manager = null
var current_wave = 1
var total_waves = 5
var time_to_next_wave = -1
var wave_in_progress = false

func _ready():
	# Find the wave manager
	wave_manager = get_node_or_null("/root/Node2D_main/WaveManager")
	
	if wave_manager:
		# Connect signals
		if wave_manager.has_signal("wave_started"):
			if not wave_manager.wave_started.is_connected(_on_wave_started):
				wave_manager.wave_started.connect(_on_wave_started)
		
		if wave_manager.has_signal("wave_completed"):
			if not wave_manager.wave_completed.is_connected(_on_wave_completed):
				wave_manager.wave_completed.connect(_on_wave_completed)
		
		if wave_manager.has_signal("countdown_tick"):
			if not wave_manager.countdown_tick.is_connected(_on_countdown_tick):
				wave_manager.countdown_tick.connect(_on_countdown_tick)
		
		# Get initial values
		if wave_manager.has_method("get_current_wave"):
			current_wave = wave_manager.get_current_wave()
		
		if wave_manager.has_method("get_total_waves"):
			total_waves = wave_manager.get_total_waves()
		
		if wave_manager.has_method("get_time_to_next_wave"):
			time_to_next_wave = wave_manager.get_time_to_next_wave()
		
		if wave_manager.has_method("is_wave_in_progress"):
			wave_in_progress = wave_manager.is_wave_in_progress()
	
	# Connect button signal
	if next_wave_button:
		if not next_wave_button.pressed.is_connected(_on_next_wave_button_pressed):
			next_wave_button.pressed.connect(_on_next_wave_button_pressed)
	
	# Initial update
	update_display()
	
	print("WaveDisplay: Ready")

func _process(delta):
	# Keep the display updated
	update_display()

func update_display():
	# Update wave label
	if wave_label:
		wave_label.text = "Wave: " + str(current_wave) + " / " + str(total_waves)
	
	# Update countdown label and button visibility
	if countdown_label:
		if time_to_next_wave >= 0:
			countdown_label.text = "Next wave in: " + str(int(time_to_next_wave)) + "s"
			countdown_label.visible = true
		elif wave_in_progress:
			countdown_label.text = "Wave in progress"
			countdown_label.visible = true
		else:
			countdown_label.visible = false
	
	if next_wave_button:
		next_wave_button.visible = time_to_next_wave >= 0

func _on_wave_started(wave_number):
	current_wave = wave_number
	wave_in_progress = true
	time_to_next_wave = -1
	update_display()

func _on_wave_completed(wave_number):
	wave_in_progress = false
	update_display()

func _on_countdown_tick(time_left):
	time_to_next_wave = time_left
	update_display()

func _on_next_wave_button_pressed():
	if wave_manager and wave_manager.has_method("skip_countdown"):
		wave_manager.skip_countdown()
		print("WaveDisplay: Next wave button pressed")
"""
		script.reload()
		wave_display.set_script(script)
	
	wave_container.add_child(wave_display)
	print("FixedUIContainer: Created wave display with proper anchoring")

# Create hero panel
func create_hero_panel():
	# Check if hero panel already exists
	hero_panel = get_node_or_null("HeroPanel")
	if hero_panel:
		print("FixedUIContainer: Found existing HeroPanel")
		return
		
	# Create hero panel
	hero_panel = Control.new()
	hero_panel.name = "HeroPanel"
	hero_panel.visible = false
	hero_panel.size = Vector2(120, 100)
	hero_panel.set_as_top_level(true)
	
	# Add script to hero panel - use the user's script
	var script = load("res://scripts/ui/hero_panel.gd")
	if script:
		hero_panel.set_script(script)
	else:
		print("FixedUIContainer: ERROR - Could not load hero_panel.gd script")
	
	add_child(hero_panel)
	print("FixedUIContainer: Created hero panel")
	
	# Connect hero panel signals
	if hero_panel.has_signal("move_button_pressed"):
		if hero_panel.move_button_pressed.is_connected(_on_move_button_pressed):
			hero_panel.move_button_pressed.disconnect(_on_move_button_pressed)
		hero_panel.move_button_pressed.connect(_on_move_button_pressed)
	
	if hero_panel.has_signal("sell_button_pressed"):
		if hero_panel.sell_button_pressed.is_connected(_on_sell_button_pressed):
			hero_panel.sell_button_pressed.disconnect(_on_sell_button_pressed)
		hero_panel.sell_button_pressed.connect(_on_sell_button_pressed)

func create_pause_button():
	# Check if pause button already exists
	pause_button = get_node_or_null("PauseButton")
	if pause_button:
		print("FixedUIContainer: Found existing PauseButton")
		return
		
	# Create a Control container for the pause button that will handle anchoring
	var pause_container = Control.new()
	pause_container.name = "PauseButtonContainer"
	pause_container.anchor_right = 1.0  # Stretch to fill width
	pause_container.anchor_bottom = 0.0  # Stick to top
	pause_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Pass mouse events through
	add_child(pause_container)
	
	# Create pause button using the Button class
	pause_button = Button.new()
	pause_button.name = "PauseButton"
	
	# Set up anchoring to right side
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.anchor_top = 0.0
	pause_button.anchor_bottom = 0.0
	
	# Set position relative to anchor (right edge)
	pause_button.offset_left = -60
	pause_button.offset_top = 10
	pause_button.offset_right = -12
	pause_button.offset_bottom = 58
	
	# Set size
	pause_button.custom_minimum_size = Vector2(48, 48)
	
	# Add script to pause button
	var script = load("res://scripts/ui/pause_button.gd")
	if script:
		pause_button.set_script(script)
		print("FixedUIContainer: Added script to pause button")
	else:
		print("FixedUIContainer: ERROR - Could not load pause_button.gd script")
		
		# If script loading fails, set up the button manually
		pause_button.text = "||"
		pause_button.pressed.connect(_on_pause_button_pressed)
	
	pause_container.add_child(pause_button)


# Create zoom controls
func create_zoom_controls():
	# Check if zoom controls already exist
	zoom_controls = get_node_or_null("ZoomControls")
	if zoom_controls:
		print("FixedUIContainer: Found existing ZoomControls")
		return
		
	# Create a Control container for the zoom controls that will handle anchoring
	var zoom_container = Control.new()
	zoom_container.name = "ZoomControlsContainer"
	zoom_container.anchor_right = 1.0  # Stretch to fill width
	zoom_container.anchor_bottom = 1.0  # Stretch to fill height
	zoom_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Pass mouse events through
	add_child(zoom_container)
	
	# Create zoom controls
	zoom_controls = Control.new()
	zoom_controls.name = "ZoomControls"
	
	# Set up anchoring to bottom right
	zoom_controls.anchor_left = 1.0
	zoom_controls.anchor_right = 1.0
	zoom_controls.anchor_top = 1.0
	zoom_controls.anchor_bottom = 1.0
	
	# Set position relative to anchor (bottom right)
	zoom_controls.offset_left = -120
	zoom_controls.offset_top = -60
	zoom_controls.offset_right = -10
	zoom_controls.offset_bottom = -10
	
	# Set size
	zoom_controls.custom_minimum_size = Vector2(110, 50)
	
	var zoom_in_button = Button.new()
	zoom_in_button.name = "ZoomInButton"
	zoom_in_button.anchor_left = 1.0
	zoom_in_button.anchor_right = 1.0
	zoom_in_button.offset_left = -40
	zoom_in_button.offset_top = 10
	zoom_in_button.offset_right = 0
	zoom_in_button.offset_bottom = 40
	zoom_in_button.text = "+"
	zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	zoom_controls.add_child(zoom_in_button)
	
	var zoom_out_button = Button.new()
	zoom_out_button.name = "ZoomOutButton"
	zoom_out_button.offset_left = 10
	zoom_out_button.offset_top = 10
	zoom_out_button.offset_right = 50
	zoom_out_button.offset_bottom = 40
	zoom_out_button.text = "-"
	zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	zoom_controls.add_child(zoom_out_button)
	
	zoom_container.add_child(zoom_controls)
	print("FixedUIContainer: Created zoom controls with proper anchoring")

# Create barrier button
func create_barrier_button():
	# Check if barrier button already exists
	barrier_button = get_node_or_null("BarrierButton")
	if barrier_button:
		return
		
	# Create a Control container for the barrier button that will handle anchoring
	var barrier_container = Control.new()
	barrier_container.name = "BarrierButtonContainer"
	barrier_container.anchor_right = 1.0  # Stretch to fill width
	barrier_container.anchor_bottom = 0.0  # Stick to top
	barrier_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Pass mouse events through
	add_child(barrier_container)
	
	# Create barrier button
	barrier_button = Button.new()
	barrier_button.name = "BarrierButton"
	
	# Set up anchoring to left side
	barrier_button.anchor_left = 0.0
	barrier_button.anchor_right = 0.0
	barrier_button.anchor_top = 0.0
	barrier_button.anchor_bottom = 0.0
	
	# Set position relative to anchor (left edge)
	barrier_button.offset_left = 10
	barrier_button.offset_top = 60
	barrier_button.offset_right = 130
	barrier_button.offset_bottom = 90
	
	barrier_button.text = "Place Barriers"
	barrier_button.pressed.connect(_on_barrier_button_pressed)
	
	barrier_container.add_child(barrier_button)

# Find existing hero shop
func find_hero_shop():
	# First check if it's already a child of this container
	hero_shop = get_node_or_null("HeroShop")
	if hero_shop:
		position_hero_shop()
		connect_hero_shop_signals()
		return
		
	# Check if hero shop exists in current UI
	var existing_ui = get_node_or_null("/root/Node2D_main/UI")
	if existing_ui:
		hero_shop = existing_ui.get_node_or_null("HeroShop")
		
		if hero_shop:
			# Reparent hero shop to this container
			hero_shop.get_parent().remove_child(hero_shop)
			add_child(hero_shop)
			position_hero_shop()
			connect_hero_shop_signals()
			return
	
	# Check if hero shop exists directly in main scene
	var main_scene = get_node_or_null("/root/Node2D_main")
	if main_scene:
		hero_shop = main_scene.get_node_or_null("HeroShop")
		
		if hero_shop:
			# Reparent hero shop to this container
			hero_shop.get_parent().remove_child(hero_shop)
			add_child(hero_shop)
			position_hero_shop()
			connect_hero_shop_signals()
			return
	

# Connect hero shop signals
func connect_hero_shop_signals():
	if hero_shop and hero_shop.has_signal("hero_purchase_requested"):
		# Disconnect any existing connections to avoid duplicates
		if hero_shop.hero_purchase_requested.is_connected(_on_hero_purchase_requested):
			hero_shop.hero_purchase_requested.disconnect(_on_hero_purchase_requested)
		
		# Connect the signal
		hero_shop.hero_purchase_requested.connect(_on_hero_purchase_requested)


# Update gold display safely
func update_gold_display():
	if gold_display:
		# Check if the script is properly attached and the function exists
		if gold_display.has_method("update_gold"):
			gold_display.update_gold(current_gold)
		else:
			# Fallback: update the label directly if it exists
			var gold_label = gold_display.get_node_or_null("GoldLabel")
			if gold_label:
				gold_label.text = str(current_gold)
	
	# Update hero shop buttons if available
	update_hero_shop_buttons(current_gold)

# Update hero shop buttons
func update_hero_shop_buttons(available_gold):
	if hero_shop and hero_shop.has_method("update_button_states"):
		# Get hero limit status from main scene
		var limit_reached = false
		if main_scene and "hero_count" in main_scene and "max_heroes" in main_scene:
			limit_reached = main_scene.hero_count >= main_scene.max_heroes
		
		# Update buttons with both gold and hero limit information
		hero_shop.update_button_states(available_gold, limit_reached)

# Function to update hero shop availability based on hero limit
func update_hero_shop_availability(available: bool):
	if hero_shop:
		if hero_shop.has_method("update_availability"):
			hero_shop.update_availability(available)
		elif hero_shop.has_method("update_button_states"):
			# Get current gold amount
			var gold = 0
			if main_scene:
				gold = main_scene.gold
			hero_shop.update_button_states(gold, !available)

# Show hero panel for a specific hero
func show_hero_panel(hero):
	if hero_panel and hero and is_instance_valid(hero):
		# Store the hero reference for continuous tracking
		tracked_hero = hero
		
		# Update panel content
		if hero_panel.has_method("show_panel_for_hero"):
			hero_panel.show_panel_for_hero(hero)
		else:
			# Use the user's show_panel method
			hero_panel.show_panel()
			
			# Update sell button text if possible
			var sell_button = hero_panel.get_node_or_null("Panel/VBoxContainer/SellButton")
			if sell_button and hero.has_method("get_sell_value"):
				var sell_value = hero.get_sell_value()
				sell_button.text = "Sell (" + str(sell_value) + ")"
		
		# Position panel above hero
		update_hero_panel_position()
	
# Hide hero panel
func hide_hero_panel():
	if hero_panel:
		if hero_panel.has_method("hide_panel"):
			hero_panel.hide_panel()
		else:
			# Just hide the panel
			hero_panel.visible = false
		
		# Stop tracking hero
		tracked_hero = null

# Update hero panel position
func update_hero_panel_position():
	if not tracked_hero or not is_instance_valid(tracked_hero) or not hero_panel:
		return
		
	# Get hero's screen position
	var hero_screen_pos = tracked_hero.global_position
	
	# Position panel above hero, centered horizontally
	var panel_width = hero_panel.size.x
	hero_panel.global_position = Vector2(hero_screen_pos.x - panel_width / 2, hero_screen_pos.y - 120)

# Get hero data from shop
func get_hero_data(hero_type: String) -> Dictionary:
	if hero_shop and hero_shop.has_method("get_hero_data"):
		return hero_shop.get_hero_data(hero_type)
	elif hero_shop and "hero_types" in hero_shop and hero_shop.hero_types.has(hero_type):
		return hero_shop.hero_types[hero_type]
	else:
		return {
			"cost": 200,
			"scene": "res://scenes/heros/fire_wizard.tscn"
		}

# Signal handlers
func _on_hero_purchase_requested(hero_type, position):
	emit_signal("hero_purchase_requested", hero_type, position)

func _on_move_button_pressed():
	if tracked_hero and is_instance_valid(tracked_hero):
		emit_signal("move_button_pressed", tracked_hero)
	else:
		hide_hero_panel()

# Update the _on_sell_button_pressed function to properly clear the grid cell
func _on_sell_button_pressed():
	if tracked_hero and is_instance_valid(tracked_hero):
		# Get grid position before emitting signal
		var hero_grid_pos = Vector2(-1, -1)
		if tracked_hero.has_method("get_grid_position"):
			hero_grid_pos = tracked_hero.get_grid_position()
		
		emit_signal("sell_button_pressed", tracked_hero)
		hide_hero_panel()
		
		# Try to clear the grid cell directly as a backup
		if hero_grid_pos != Vector2(-1, -1):
			var grid_system = get_node_or_null("/root/Node2D_main/GridSystem")
			if grid_system:
				grid_system.unregister_hero(hero_grid_pos)
				if grid_system.has_method("set_cell_empty"):
					grid_system.set_cell_empty(hero_grid_pos)
	else:
		hide_hero_panel()

func _on_barrier_button_pressed():
	emit_signal("barrier_button_pressed")

func _on_pause_button_pressed():
	is_game_paused = !is_game_paused
	
	# Update button appearance
	if is_game_paused:
		var resume_texture = load("res://assets/ui/play_button.png")
		if resume_texture and pause_button is TextureButton:
			pause_button.texture_normal = resume_texture
		elif pause_button is Button:
			pause_button.text = "▶"
	else:
		var pause_texture = load("res://assets/ui/pause_button.png")
		if pause_texture and pause_button is TextureButton:
			pause_button.texture_normal = pause_texture
		elif pause_button is Button:
			pause_button.text = "||"
	# Emit signal
	emit_signal("pause_toggled", is_game_paused)

func _on_zoom_in_pressed():
	# Try to use the camera controller first
	if camera_controller and camera_controller.has_method("zoom_in"):
		camera_controller.zoom_in()
	# Try to find the camera and zoom in directly
	elif camera_controller:
		# Use the camera controller's target_zoom
		var new_zoom = camera_controller.target_zoom * 1.2  # Increase by 20%
		camera_controller.target_zoom = new_zoom
	# Try main scene's zoom_in method
	elif main_scene and main_scene.has_method("zoom_in"):
		main_scene.zoom_in()
	# Fallback to direct camera manipulation
	else:
		var camera = get_viewport().get_camera_2d()
		if camera:
			# Zoom in by increasing the zoom factor (making objects appear larger)
			camera.zoom = camera.zoom * 1.2  # Increase by 20%


func _on_zoom_out_pressed():
	
	# Try to use the camera controller first
	if camera_controller and camera_controller.has_method("zoom_out"):
		camera_controller.zoom_out()
	# Try to find the camera and zoom out directly
	elif camera_controller:
		# Use the camera controller's target_zoom
		var new_zoom = camera_controller.target_zoom * 0.8  # Decrease by 20%
		camera_controller.target_zoom = new_zoom
	# Try main scene's zoom_out method
	elif main_scene and main_scene.has_method("zoom_out"):
		main_scene.zoom_out()
	# Fallback to direct camera manipulation
	else:
		var camera = get_viewport().get_camera_2d()
		if camera:
			# Zoom out by decreasing the zoom factor (making objects appear smaller)
			camera.zoom = camera.zoom * 0.8  # Decrease by 20%


func _on_next_wave_button_pressed():
	var wave_manager = get_node_or_null("/root/Node2D_main/WaveManager")
	if wave_manager and wave_manager.has_method("skip_countdown"):
		wave_manager.skip_countdown()

# Update wave display
func update_wave_display(current_wave, total_waves, time_to_next_wave = -1):
	if wave_display:
		var wave_label = wave_display.get_node_or_null("WaveLabel")
		var countdown_label = wave_display.get_node_or_null("CountdownLabel")
		var next_wave_button = wave_display.get_node_or_null("NextWaveButton")
		
		if wave_label:
			wave_label.text = "Wave: " + str(current_wave) + " / " + str(total_waves)
		
		if countdown_label:
			if time_to_next_wave >= 0:
				countdown_label.text = "Next wave in: " + str(int(time_to_next_wave)) + "s"
				countdown_label.visible = true
			else:
				countdown_label.text = "Wave in progress"
				countdown_label.visible = true
		
		if next_wave_button:
			next_wave_button.visible = time_to_next_wave >= 0
# Position hero shop at bottom center
func position_hero_shop():
	if hero_shop:
		# Make sure it's set to top level
		hero_shop.set_as_top_level(true)
		
		# Position at bottom center
		var viewport_size = get_viewport().size
		hero_shop.position = Vector2(viewport_size.x / 2 - hero_shop.size.x / 2, viewport_size.y - hero_shop.size.y - 10)

# Show game over screen
func show_game_over():
	# Create game over panel
	var viewport_size = get_viewport().size

	var game_over_panel = Panel.new()
	game_over_panel.name = "GameOverPanel"
	game_over_panel.anchor_left = 0.5
	game_over_panel.anchor_top = 0.5
	game_over_panel.anchor_right = 0.5
	game_over_panel.anchor_bottom = 0.5
	game_over_panel.offset_left = -200
	game_over_panel.offset_top = -100
	game_over_panel.offset_right = 200
	game_over_panel.offset_bottom = 100
	game_over_panel.set_as_top_level(true)
	add_child(game_over_panel)
	
	# Create game over label
	var game_over_label = Label.new()
	game_over_label.text = "GAME OVER"
	game_over_label.anchor_right = 1.0
	game_over_label.anchor_bottom = 0.7
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 48)
	game_over_panel.add_child(game_over_label)
	
	# Create restart button
	var restart_button = Button.new()
	restart_button.text = "Restart Game"
	restart_button.anchor_left = 0.5
	restart_button.anchor_top = 0.7
	restart_button.anchor_right = 0.5
	restart_button.anchor_bottom = 0.9
	restart_button.offset_left = -100
	restart_button.offset_right = 100
	restart_button.pressed.connect(_on_restart_button_pressed)
	game_over_panel.add_child(restart_button)
	
	
func _on_restart_button_pressed():
	# Reload the current scene
	get_tree().reload_current_scene()
	
	# Unpause the game
	get_tree().paused = false
	

# Add this new function to handle the pause_toggled signal
func _on_pause_toggled(is_paused):
	is_game_paused = is_paused
	heroes_paused = is_paused
	emit_signal("pause_toggled", is_game_paused)

# Make sure the main scene has references to this UI container
func ensure_main_scene_references():
	var main_scene = get_node_or_null("/root/Node2D_main")
	if main_scene:
		# Set UI reference in main scene
		if "ui" in main_scene:
			main_scene.ui = self
		
		# Set hero_shop reference in main scene
		if "hero_shop" in main_scene and hero_shop:
			main_scene.hero_shop = hero_shop
		
		# Connect signals directly to main scene
		if has_signal("hero_purchase_requested") and main_scene.has_method("_on_hero_purchase_requested"):
			if not hero_purchase_requested.is_connected(main_scene._on_hero_purchase_requested):
				hero_purchase_requested.connect(main_scene._on_hero_purchase_requested)
		
		if has_signal("barrier_button_pressed") and main_scene.has_method("_on_barrier_button_pressed"):
			if not barrier_button_pressed.is_connected(main_scene._on_barrier_button_pressed):
				barrier_button_pressed.connect(main_scene._on_barrier_button_pressed)
		
		if has_signal("move_button_pressed") and main_scene.has_method("_on_move_button_pressed"):
			if not move_button_pressed.is_connected(main_scene._on_move_button_pressed):
				move_button_pressed.connect(main_scene._on_move_button_pressed)
		
		if has_signal("sell_button_pressed") and main_scene.has_method("_on_sell_button_pressed"):
			if not sell_button_pressed.is_connected(main_scene._on_sell_button_pressed):
				sell_button_pressed.connect(main_scene._on_sell_button_pressed)
		
		if has_signal("pause_toggled") and main_scene.has_method("_on_pause_toggled"):
			if not pause_toggled.is_connected(main_scene._on_pause_toggled):
				pause_toggled.connect(main_scene._on_pause_toggled)


# Handle window resize to keep pause button in position

# Create hero count display
func create_hero_count_display():
	# Check if hero count display already exists
	var hero_count_display = get_node_or_null("HeroCountDisplay")
	if hero_count_display:
		return
		
	# Create a Control container for the hero count display
	var hero_count_container = Control.new()
	hero_count_container.name = "HeroCountContainer"
	hero_count_container.anchor_right = 1.0  # Stretch to fill width
	hero_count_container.anchor_bottom = 0.0  # Stick to top
	hero_count_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Pass mouse events through
	add_child(hero_count_container)
	
	# Create hero count display
	hero_count_display = Control.new()
	hero_count_display.name = "HeroCountDisplay"
	
	# Set up anchoring to right side
	hero_count_display.anchor_left = 1.0
	hero_count_display.anchor_right = 1.0
	hero_count_display.anchor_top = 0.0
	hero_count_display.anchor_bottom = 0.0
	
	# Set position relative to anchor (right edge)
	hero_count_display.offset_left = -180
	hero_count_display.offset_top = 10
	hero_count_display.offset_right = -70
	hero_count_display.offset_bottom = 50
	
	# Set size
	hero_count_display.custom_minimum_size = Vector2(110, 40)
	
	var background = Panel.new()
	background.name = "Background"
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	# Add a visible style to the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray, semi-transparent
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	background.add_theme_stylebox_override("panel", style)
	hero_count_display.add_child(background)
	
	var hero_count_label = Label.new()
	hero_count_label.name = "HeroCountLabel"
	hero_count_label.anchor_right = 1.0
	hero_count_label.anchor_bottom = 1.0
	hero_count_label.offset_left = 10
	hero_count_label.offset_top = 5
	hero_count_label.offset_right = -10
	hero_count_label.offset_bottom = -5
	hero_count_label.text = "Heroes: 0/10"
	hero_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero_count_display.add_child(hero_count_label)
	
	# Add script to hero count display
	var script = GDScript.new()
	script.source_code = """
extends Control

@onready var hero_count_label = $HeroCountLabel
var current_count = 0
var max_count = 10

func _ready():
	# Initialize with zero heroes
	update_count(0, max_count)
	
	print("HeroCountDisplay: Ready")

func update_count(count: int, max_heroes: int = 10):
	current_count = count
	max_count = max_heroes
	if hero_count_label:
		hero_count_label.text = "Heroes: " + str(count) + "/" + str(max_heroes)
	
	# Update color based on how close to limit
	if count >= max_heroes:
		hero_count_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Red when at limit
	elif count >= max_heroes * 0.8:
		hero_count_label.add_theme_color_override("font_color", Color(1, 0.7, 0.3))  # Orange when close to limit
	else:
		hero_count_label.add_theme_color_override("font_color", Color(1, 1, 1))  # White when well below limit
	
	print("HeroCountDisplay: Updated to " + str(count) + "/" + str(max_heroes) + " heroes")
"""
	script.reload()
	hero_count_display.set_script(script)
	
	hero_count_container.add_child(hero_count_display)
	print("FixedUIContainer: Created hero count display with proper anchoring")
	
	# Initialize hero count display
	update_hero_count_display()

# Update hero count display
func update_hero_count_display():
	var hero_count_display = get_node_or_null("HeroCountContainer/HeroCountDisplay")
	if hero_count_display and hero_count_display.has_method("update_count"):
		var count = 0
		var max_heroes = 10
		
		if main_scene:
			if "hero_count" in main_scene:
				count = main_scene.hero_count
			if "max_heroes" in main_scene:
				max_heroes = main_scene.max_heroes
		
		hero_count_display.update_count(count, max_heroes)
