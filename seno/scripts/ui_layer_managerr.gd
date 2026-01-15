extends CanvasLayer

# Signals to relay from UI elements
signal hero_purchase_requested(hero_type, position)
signal move_button_pressed(hero)
signal sell_button_pressed(hero)
signal barrier_button_pressed

# References to UI elements
var hero_shop
var hero_panel
@onready var gold_label = $Control/GlobalLabel
@onready var barrier_button = $Control/BarrierButton
@onready var zoom_indicator = $Control/ZoomIndicator

# Camera reference for coordinate conversion
var camera

# Track the currently selected hero for panel positioning
var tracked_hero = null

# Pause button variables
@onready var pause_button :TextureButton = $Control/PauseButton
var pause_texture: Texture2D
var resume_texture: Texture2D
var is_game_paused: bool = false

func _ready():
	print("UI: _ready() called")

	# Set a high layer to ensure UI is on top
	layer = 10

	# Find camera for coordinate conversion
	camera = get_viewport().get_camera_2d()
	if camera:
		print("UI: Found camera at " + str(camera.get_path()))
	else:
		print("UI: WARNING - Camera not found, screen position calculations may be incorrect")

	# Initialize UI elements
	initialize_ui_elements()

	# Make sure the pause button is created and properly positioned
	call_deferred("create_pause_button")

	print("UI: Ready")

func _process(delta):
	# Continuously update hero panel position if we're tracking a hero
	if tracked_hero and is_instance_valid(tracked_hero) and hero_panel and hero_panel.visible:
		# Update camera reference if needed
		if not camera or not is_instance_valid(camera):
			camera = get_viewport().get_camera_2d()
		
		# Convert world position to screen position
		var screen_position = world_to_screen_position(tracked_hero.global_position)
		
		# Position the panel above the hero with fixed offset regardless of zoom
		hero_panel.global_position = Vector2(screen_position.x - hero_panel.size.x / 2, screen_position.y - 120)
	elif tracked_hero and !is_instance_valid(tracked_hero):
		# Hero is no longer valid, hide the panel
		if hero_panel:
			hero_panel.visible = false
		tracked_hero = null
		print("UI: Tracked hero is no longer valid, hiding panel")

# Signal handler methods
func _on_hero_purchase_requested(hero_type, position):
	print("UI: Hero purchase requested: " + hero_type + " at position: " + str(position))

	# Convert screen position to world position
	var world_position = screen_to_world_position(position)
	print("UI: Converted to world position: " + str(world_position))

	emit_signal("hero_purchase_requested", hero_type, world_position)

func _on_move_button_pressed():
	print("UI: Move button pressed")
	if tracked_hero and is_instance_valid(tracked_hero):
		print("UI: Sending move signal for hero: " + str(tracked_hero.name))
		emit_signal("move_button_pressed", tracked_hero)
	else:
		print("UI: ERROR - No hero tracked for move button")
		# Hide the panel since the hero is no longer valid
		if hero_panel:
			hero_panel.visible = false
		tracked_hero = null

func _on_sell_button_pressed():
	print("UI: Sell button pressed")
	if tracked_hero and is_instance_valid(tracked_hero):
		print("UI: Sending sell signal for hero: " + str(tracked_hero.name))
		emit_signal("sell_button_pressed", tracked_hero)
	else:
		print("UI: ERROR - No hero tracked for sell button")
		# Hide the panel since the hero is no longer valid
		if hero_panel:
			hero_panel.visible = false
		tracked_hero = null

func _on_barrier_button_pressed():
	print("UI: Barrier button pressed")
	emit_signal("barrier_button_pressed")

# Helper function to convert world position to screen position
func world_to_screen_position(world_pos: Vector2) -> Vector2:
	# Update camera reference if needed
	if not camera or not is_instance_valid(camera):
		camera = get_viewport().get_camera_2d()

	if camera:
		var viewport_size = Vector2(get_viewport().size)  # Convert to Vector2 explicitly
		var camera_pos = camera.global_position
		var zoom = camera.zoom
		
		# Calculate screen position based on world position, camera position, and zoom
		var screen_pos = (world_pos - camera_pos) * zoom + viewport_size/2
		return screen_pos
	else:
		print("UI: WARNING - Cannot convert to screen position, camera is null")
		return world_pos

# Helper function to convert screen position to world position
func screen_to_world_position(screen_pos: Vector2) -> Vector2:
	# Update camera reference if needed
	if not camera or not is_instance_valid(camera):
		camera = get_viewport().get_camera_2d()

	if camera:
		var viewport_size = Vector2(get_viewport().size)
		var camera_pos = camera.global_position
		var zoom = camera.zoom
		
		# Calculate world position based on screen position, camera position, and zoom
		var world_pos = camera_pos + (screen_pos - viewport_size/2) / zoom
		return world_pos
	else:
		print("UI: WARNING - Cannot convert to world position, camera is null")
		return screen_pos

func initialize_ui_elements():
	# Create Control node to hold all UI elements if it doesn't exist
	var control = get_node_or_null("Control")
	if not control:
		control = Control.new()
		control.name = "Control"
		control.anchor_right = 1.0
		control.anchor_bottom = 1.0
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(control)
		print("UI: Created Control node for UI elements")

	# Create HeroPanel if it doesn't exist
	create_hero_panel()

	# Find or create HeroShop
	setup_hero_shop()

	# Setup gold label
	setup_gold_label(control)

	# Setup barrier button
	setup_barrier_button(control)

	# Setup zoom indicator
	setup_zoom_indicator(control)

	# Setup wave display
	setup_wave_display(control)

func setup_hero_shop():
	hero_shop = get_node_or_null("HeroShop")
	if hero_shop:
		print("UI: Found HeroShop at " + str(hero_shop.get_path()))
		
		# Connect signals from HeroShop
		if hero_shop.has_signal("hero_purchase_requested"):
			if hero_shop.hero_purchase_requested.is_connected(_on_hero_purchase_requested):
				hero_shop.hero_purchase_requested.disconnect(_on_hero_purchase_requested)
			hero_shop.hero_purchase_requested.connect(_on_hero_purchase_requested)
			print("UI: Connected HeroShop hero_purchase_requested signal")
		else:
			print("UI: ERROR - HeroShop does not have hero_purchase_requested signal")
			
		# Center the shop horizontally at the bottom of the screen
		var viewport_size = get_viewport().size
		hero_shop.anchor_left = 0.5
		hero_shop.anchor_right = 0.5
		hero_shop.anchor_top = 1.0
		hero_shop.anchor_bottom = 1.0
		hero_shop.offset_left = -hero_shop.size.x / 2
		hero_shop.offset_right = hero_shop.size.x / 2
		hero_shop.offset_top = -hero_shop.size.y - 10
		hero_shop.offset_bottom = -10
		print("UI: Centered HeroShop at bottom of screen")
	else:
		print("UI: HeroShop not found, creating one")
		
		# Try to load HeroShop scene
		var hero_shop_scene = load("res://scenes/ui/HeroShop.tscn")
		if hero_shop_scene:
			hero_shop = hero_shop_scene.instantiate()
			hero_shop.name = "HeroShop"
			add_child(hero_shop)
			
			# Center the shop horizontally at the bottom of the screen
			var viewport_size = get_viewport().size
			hero_shop.anchor_left = 0.5
			hero_shop.anchor_right = 0.5
			hero_shop.anchor_top = 1.0
			hero_shop.anchor_bottom = 1.0
			hero_shop.offset_left = -hero_shop.size.x / 2
			hero_shop.offset_right = hero_shop.size.x / 2
			hero_shop.offset_top = -hero_shop.size.y - 10
			hero_shop.offset_bottom = -10
			
			# Connect signals
			if hero_shop.has_signal("hero_purchase_requested"):
				hero_shop.hero_purchase_requested.connect(_on_hero_purchase_requested)
			
			print("UI: Created and centered HeroShop at bottom of screen")
		else:
			print("UI: ERROR - Could not load HeroShop scene")

func setup_gold_label(control):
	if not gold_label:
		print("UI: GoldLabel not found, creating one")
		gold_label = Label.new()
		gold_label.name = "GlobalLabel"
		gold_label.text = "Gold: 0"
		
		# Anchor to top left
		gold_label.anchor_left = 0
		gold_label.anchor_top = 0
		gold_label.offset_left = 10
		gold_label.offset_top = 10
		
		control.add_child(gold_label)
		print("UI: Created GoldLabel")
	else:
		print("UI: Found GoldLabel at " + str(gold_label.get_path()))

func setup_barrier_button(control):
	if not barrier_button:
		print("UI: BarrierButton not found, creating one")
		barrier_button = Button.new()
		barrier_button.name = "BarrierButton"
		barrier_button.text = "Place Barriers"
		
		# Anchor to top left, below gold label
		barrier_button.anchor_left = 0
		barrier_button.anchor_top = 0
		barrier_button.offset_left = 10
		barrier_button.offset_top = 40
		barrier_button.custom_minimum_size = Vector2(120, 30)
		
		barrier_button.pressed.connect(_on_barrier_button_pressed)
		control.add_child(barrier_button)
		print("UI: Created BarrierButton")
	else:
		print("UI: Found BarrierButton at " + str(barrier_button.get_path()))
		if not barrier_button.pressed.is_connected(_on_barrier_button_pressed):
			barrier_button.pressed.connect(_on_barrier_button_pressed)

func setup_zoom_indicator(control):
	if not zoom_indicator:
		print("UI: ZoomIndicator not found, creating one")
		zoom_indicator = Label.new()
		zoom_indicator.name = "ZoomIndicator"
		zoom_indicator.text = "Zoom: 100%"
		
		# Anchor to top right
		zoom_indicator.anchor_left = 1
		zoom_indicator.anchor_right = 1
		zoom_indicator.anchor_top = 0
		zoom_indicator.offset_left = -100
		zoom_indicator.offset_right = -70  # Move further right to make room for pause button
		zoom_indicator.offset_top = 10
		
		control.add_child(zoom_indicator)
		print("UI: Created ZoomIndicator")
	else:
		print("UI: Found ZoomIndicator at " + str(zoom_indicator.get_path()))
		
		# Make sure it's properly anchored
		zoom_indicator.anchor_left = 1
		zoom_indicator.anchor_right = 1
		zoom_indicator.anchor_top = 0
		zoom_indicator.offset_left = -100
		zoom_indicator.offset_right = -70  # Move further right to make room for pause button
		zoom_indicator.offset_top = 10

# Create HeroPanel manually if it doesn't exist
func create_hero_panel():
	# Remove any existing hero panels from heroes
	var heroes = get_tree().get_nodes_in_group("heroes")
	for hero in heroes:
		if is_instance_valid(hero):
			var hero_panel = hero.get_node_or_null("HeroPanel")
			if hero_panel:
				hero_panel.queue_free()
				print("UI: Removed HeroPanel from hero: " + hero.name)

	# Check if we already have a hero panel in the UI
	hero_panel = get_node_or_null("HeroPanel")
	if hero_panel:
		print("UI: Found HeroPanel at " + str(hero_panel.get_path()))
		
		# Connect signals from HeroPanel
		if hero_panel.has_signal("move_button_pressed"):
			if not hero_panel.move_button_pressed.is_connected(_on_move_button_pressed):
				hero_panel.move_button_pressed.connect(_on_move_button_pressed)
				print("UI: Connected HeroPanel move_button_pressed signal")
		else:
			print("UI: ERROR - HeroPanel does not have move_button_pressed signal")
			
		if hero_panel.has_signal("sell_button_pressed"):
			if not hero_panel.sell_button_pressed.is_connected(_on_sell_button_pressed):
				hero_panel.sell_button_pressed.connect(_on_sell_button_pressed)
				print("UI: Connected HeroPanel sell_button_pressed signal")
		else:
			print("UI: ERROR - HeroPanel does not have sell_button_pressed signal")
		
		# Hide panel initially
		hero_panel.visible = false
		print("UI: Set HeroPanel initial visibility to false")
		
		return

	print("UI: HeroPanel not found, creating one")

	# Create the panel manually
	hero_panel = Control.new()
	hero_panel.name = "HeroPanel"
	hero_panel.visible = false
	hero_panel.custom_minimum_size = Vector2(120, 100)
	hero_panel.size = Vector2(120, 100)
	
	# Load and attach the HeroPanel script
	var script = load("res://scripts/ui/HeroPanel.gd")
	if script:
		hero_panel.set_script(script)
		print("UI: Attached HeroPanel script")
	else:
		print("UI: ERROR - Could not load HeroPanel script")
	
	add_child(hero_panel)
	
	# Make sure the panel is not affected by camera zoom
	hero_panel.set_as_top_level(true)
	
	# Connect signals
	if hero_panel.has_signal("move_button_pressed"):
		hero_panel.move_button_pressed.connect(_on_move_button_pressed)
	
	if hero_panel.has_signal("sell_button_pressed"):
		hero_panel.sell_button_pressed.connect(_on_sell_button_pressed)
	
	print("UI: Created HeroPanel with script attached")

# Show/hide and position hero panel
func show_hero_panel(world_position: Vector2, show: bool = true, hero = null):
	if not hero_panel:
		create_hero_panel()
		if not hero_panel:
			print("UI: ERROR - Cannot show HeroPanel, failed to create")
			return

	print("UI: show_hero_panel called with position: " + str(world_position) + ", show: " + str(show) + ", hero: " + str(hero))

	if show and hero and is_instance_valid(hero):
		# Store the hero reference for continuous tracking
		tracked_hero = hero
		print("UI: Tracking hero: " + str(tracked_hero.name))
		
		# Convert world position to screen position
		var screen_position = world_to_screen_position(world_position)
		print("UI: Converted to screen position: " + str(screen_position))
		
		# Position panel above hero, centered horizontally
		# Add a vertical offset to ensure it's not directly under the cursor
		var panel_width = hero_panel.size.x
		hero_panel.global_position = screen_position - Vector2(panel_width / 2, 120)  # Increased vertical offset
		print("UI: Set HeroPanel position to: " + str(hero_panel.global_position))
		
		# Make sure the panel is visible using the new show_panel method
		if hero_panel.has_method("show_panel"):
			hero_panel.show_panel()
			print("UI: Called HeroPanel show_panel method")
		else:
			hero_panel.visible = true
			print("UI: Set HeroPanel visibility to true")
	else:
		# Stop tracking hero
		if tracked_hero:
			print("UI: Stopped tracking hero: " + str(tracked_hero.name))
		tracked_hero = null
		
		# Hide the panel
		hero_panel.visible = false
		print("UI: Set HeroPanel visibility to false")

# Update gold display
func update_gold_display(amount: int):
	if gold_label:
		gold_label.text = "Gold: " + str(amount)
		print("UI: Updated gold display to: " + str(amount))
	else:
		# Try to find the gold label if it doesn't exist
		gold_label = get_node_or_null("Control/GlobalLabel")
		if gold_label:
			gold_label.text = "Gold: " + str(amount)
			print("UI: Found and updated gold label to: " + str(amount))
		else:
			# Create gold label if it doesn't exist
			var control = get_node_or_null("Control")
			if control:
				gold_label = Label.new()
				gold_label.name = "GlobalLabel"
				gold_label.text = "Gold: " + str(amount)
				gold_label.anchor_left = 0
				gold_label.anchor_top = 0
				gold_label.offset_left = 10
				gold_label.offset_top = 10
				control.add_child(gold_label)
				print("UI: Created new gold label with value: " + str(amount))
			else:
				print("UI: ERROR - Cannot create gold label, Control node not found")

# Update hero shop button states
func update_hero_shop_buttons(available_gold: int):
	if hero_shop and hero_shop.has_method("update_button_states"):
		hero_shop.update_button_states(available_gold)
	else:
		print("UI: ERROR - Cannot update hero shop buttons, hero_shop is null or missing method")

# Update zoom indicator
func update_zoom_indicator(zoom_level: float):
	if zoom_indicator:
		var zoom_percent = int(zoom_level * 100)
		zoom_indicator.text = "Zoom: " + str(zoom_percent) + "%"
	else:
		print("UI: ERROR - Cannot update zoom indicator, zoom_indicator is null")

# Get hero data from shop
func get_hero_data(hero_type: String) -> Dictionary:
	if hero_shop and hero_shop.has_method("get_hero_data"):
		return hero_shop.get_hero_data(hero_type)
	elif hero_shop and "hero_types" in hero_shop and hero_shop.hero_types.has(hero_type):
		return hero_shop.hero_types[hero_type]
	else:
		print("UI: ERROR - Cannot get hero data, hero_shop is null or missing method")
		# Return default data
		return {
			"cost": 200,
			"scene": "res://scenes/red_wizard_woman.tscn"
		}

# Create pause button
func create_pause_button():
	# Get the Control node
	var control = get_node_or_null("Control")
	if not control:
		control = Control.new()
		control.name = "Control"
		control.anchor_right = 1.0
		control.anchor_bottom = 1.0
		add_child(control)

	# Check if pause button already exists
	if is_instance_valid(pause_button):
		print("UI: Found existing PauseButton")
		pause_button.queue_free()

	# Load textures
	pause_texture = load("res://assets/ui/pause_button.png")
	resume_texture = load("res://assets/ui/play_button.png")

	# Create button
	pause_button = TextureButton.new()
	pause_button.name = "PauseButton"
	pause_button.texture_normal = pause_texture
	pause_button.visible = true
	pause_button.ignore_texture_size = true
	pause_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	pause_button.custom_minimum_size = Vector2(48, 48)
	pause_button.size = Vector2(48, 48)
	pause_button.tooltip_text = "Pause Game"
	pause_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Position at top center
	pause_button.anchor_left = 0.5
	pause_button.anchor_right = 0.5
	pause_button.anchor_top = 0
	pause_button.offset_left = -24
	pause_button.offset_right = 24
	pause_button.offset_top = 10
	pause_button.offset_bottom = 58

	# Connect signals
	if pause_button.pressed.is_connected(_on_pause_button_pressed):
		pause_button.pressed.disconnect(_on_pause_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)

	if pause_button.mouse_entered.is_connected(_on_pause_button_mouse_entered):
		pause_button.mouse_entered.disconnect(_on_pause_button_mouse_entered)
	pause_button.mouse_entered.connect(_on_pause_button_mouse_entered)

	if pause_button.mouse_exited.is_connected(_on_pause_button_mouse_exited):
		pause_button.mouse_exited.disconnect(_on_pause_button_mouse_exited)
	pause_button.mouse_exited.connect(_on_pause_button_mouse_exited)

	# Add to UI
	control.add_child(pause_button)

	print("UI: Created pause button at top center")

# Handle pause button interactions
func _on_pause_button_pressed():
	print("UI: Pause button pressed!")

	# Toggle pause state
	is_game_paused = !is_game_paused

	# Update button appearance
	if is_game_paused:
		if resume_texture:
			pause_button.texture_normal = resume_texture
		pause_button.tooltip_text = "Resume Game"
		print("UI: Game paused")
	else:
		if pause_texture:
			pause_button.texture_normal = pause_texture
		pause_button.tooltip_text = "Pause Game"
		print("UI: Game resumed")

	# Get main scene and call pause function
	var main_scene = get_node_or_null("/root/Node2D_main")
	if main_scene and main_scene.has_method("_on_pause_button_toggled"):
		main_scene._on_pause_button_toggled(is_game_paused)
		print("UI: Sent pause toggle signal to main scene: " + str(is_game_paused))
	else:
		print("UI: WARNING - Could not find main scene or _on_pause_button_toggled method")

func _on_pause_button_mouse_entered():
	# Scale up slightly on hover
	pause_button.scale = Vector2(1.1, 1.1)

func _on_pause_button_mouse_exited():
	# Return to normal scale
	pause_button.scale = Vector2(1.0, 1.0)

func setup_wave_display(control):
	print("UI: setup_wave_display() called")

	# Check if wave display already exists
	var wave_display = control.get_node_or_null("WaveDisplay")
	print("UI: Existing WaveDisplay: ", wave_display)

	if not wave_display:
		print("UI: WaveDisplay not found, creating one")
		
		# Try to load WaveDisplay scene
		var wave_display_scene = load("res://scenes/ui/WaveDisplay.tscn")
		print("UI: Loaded WaveDisplay scene: ", wave_display_scene)
		
		if wave_display_scene:
			wave_display = wave_display_scene.instantiate()
			wave_display.name = "WaveDisplay"
			
			# Position at top center
			wave_display.anchor_left = 0.5
			wave_display.anchor_right = 0.5
			wave_display.anchor_top = 0
			wave_display.offset_left = -100
			wave_display.offset_right = 100
			wave_display.offset_top = 70  # Below pause button
			wave_display.offset_bottom = 130
			
			control.add_child(wave_display)
			print("UI: Created WaveDisplay from scene")
		else:
			print("UI: ERROR - Could not load WaveDisplay scene, creating fallback")
			
			# Create a basic wave display as fallback
			wave_display = Control.new()
			wave_display.name = "WaveDisplay"
			
			# Position at top center
			wave_display.anchor_left = 0.5
			wave_display.anchor_right = 0.5
			wave_display.anchor_top = 0
			wave_display.offset_left = -100
			wave_display.offset_right = 100
			wave_display.offset_top = 70  # Below pause button
			wave_display.offset_bottom = 130
			
			var panel = Panel.new()
			panel.anchor_right = 1.0
			panel.anchor_bottom = 1.0
			wave_display.add_child(panel)
			
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
			next_wave_button.anchor_top = 1.0
			next_wave_button.anchor_right = 0.5
			next_wave_button.anchor_bottom = 1.0
			next_wave_button.offset_left = -50
			next_wave_button.offset_top = 5
			next_wave_button.offset_right = 50
			next_wave_button.offset_bottom = 35
			next_wave_button.text = "Start Wave"
			wave_display.add_child(next_wave_button)
			
			# Add script to wave display
			var script = GDScript.new()
			script.source_code = """
extends Control

@onready var wave_label = $WaveLabel
@onready var countdown_label = $CountdownLabel
@onready var next_wave_button = $NextWaveButton

var wave_manager = null

func _ready():
	# Find the wave manager
	wave_manager = get_node_or_null("/root/Node2D_main/WaveManager")

	if not wave_manager:
		print("WaveDisplay: WaveManager not found!")
		return

	# Connect signals
	if wave_manager.has_signal("wave_started"):
		wave_manager.wave_started.connect(_on_wave_started)

	if wave_manager.has_signal("wave_completed"):
		wave_manager.wave_completed.connect(_on_wave_completed)

	if wave_manager.has_signal("countdown_tick"):
		wave_manager.countdown_tick.connect(_on_countdown_tick)

	# Connect button signal
	next_wave_button.pressed.connect(_on_next_wave_button_pressed)

	# Initial update
	update_display()

	print("WaveDisplay: Ready")

func _process(delta):
	# Keep the display updated
	update_display()

func update_display():
	if not wave_manager:
		return

	# Update wave label
	var current_wave = wave_manager.get_current_wave()
	var total_waves = wave_manager.get_total_waves()
	wave_label.text = "Wave: " + str(current_wave) + " / " + str(total_waves)

	# Update countdown label and button visibility
	if wave_manager.is_countdown_active():
		var time_left = wave_manager.get_time_to_next_wave()
		countdown_label.text = "Next wave in: " + str(int(time_left)) + "s"
		countdown_label.visible = true
		next_wave_button.visible = true
	elif wave_manager.is_wave_in_progress():
		countdown_label.text = "Wave in progress"
		countdown_label.visible = true
		next_wave_button.visible = false
	else:
		countdown_label.visible = false
		next_wave_button.visible = false

func _on_wave_started(wave_number):
	update_display()

func _on_wave_completed(wave_number):
	update_display()

func _on_countdown_tick(time_left):
	# This is handled in update_display, but we could optimize by updating only when needed
	pass

func _on_next_wave_button_pressed():
	if wave_manager and wave_manager.is_countdown_active():
		wave_manager.skip_countdown()
		print("WaveDisplay: Next wave button pressed")
"""
			script.reload()
			wave_display.set_script(script)
			
			control.add_child(wave_display)
			print("UI: Created fallback WaveDisplay")
	else:
		print("UI: Found existing WaveDisplay at ", wave_display.get_path())

func show_game_over():
	# Get the Control node
	var control = get_node_or_null("Control")
	if not control:
		control = Control.new()
		control.name = "Control"
		control.anchor_right = 1.0
		control.anchor_bottom = 1.0
		add_child(control)

	# Create game over panel
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
	control.add_child(game_over_panel)

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

	print("UI: Showed game over screen")

func _on_restart_button_pressed():
	# Reload the current scene
	get_tree().reload_current_scene()

	# Unpause the game
	get_tree().paused = false

	print("UI: Restarting game")
