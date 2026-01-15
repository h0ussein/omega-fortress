extends Node2D

# Game state
var gold: int = 3000
var game_paused: bool = false
var game_over_triggered: bool = false
var hero_count: int = 0  # Track the number of heroes
var max_heroes: int = 10  # Maximum number of heroes allowed

# References to game components
var grid_system
@onready var ui = $FixedUIContainer
var hero_shop
var barrier_placer
var wave_manager
var wave_display_manager
var selected_hero = null
var placing_hero = false
var placing_hero_type = ""
var moving_hero = false
var placing_barrier = false

# Hero preview for placement
var hero_preview = null

func _ready():
	# Check if MusicManager already exists
	if not get_node_or_null("/root/MusicManager"):
		print("Creating MusicManager manually")
		var music_manager_script = load("res://path/to/MusicManager.gd")
		var music_manager = music_manager_script.new()
		music_manager.name = "MusicManager"
		get_tree().root.add_child(music_manager)
	
	# Find grid system
	grid_system = get_node_or_null("GridSystem")
	# Find UI - try different paths
	ui = get_node_or_null("UI")
	if not ui:
		ui = get_node_or_null("ui")  # Try lowercase
	if not ui:
		ui = get_node_or_null("FixedUIContainer")  # Try the new UI container

	if ui:
		# Connect UI signals
		if ui.has_signal("hero_purchase_requested"):
			ui.hero_purchase_requested.connect(_on_hero_purchase_requested)
		
		if ui.has_signal("move_button_pressed"):
			ui.move_button_pressed.connect(_on_move_button_pressed)
		
		if ui.has_signal("sell_button_pressed"):
			ui.sell_button_pressed.connect(_on_sell_button_pressed)		
		if ui.has_signal("barrier_button_pressed"):
			ui.barrier_button_pressed.connect(_on_barrier_button_pressed)
			
		if ui.has_signal("pause_toggled"):
			ui.pause_toggled.connect(_on_pause_button_toggled)

	# Find hero shop - try different paths
	hero_shop = get_node_or_null("UI/HeroShop")
	if not hero_shop and ui:
		hero_shop = ui.get_node_or_null("HeroShop")
	# Find barrier placer
	barrier_placer = get_node_or_null("BarrierPlacer")
	
	# Find wave manager
	wave_manager = get_node_or_null("WaveManager")
	if wave_manager:
		print("MainScene: Found WaveManag;-[r at " + str(wave_manager.get_path()))
	else:
		# Try to find it with a different path
		var potential_managers = get_tree().get_nodes_in_group("wave_manager")
		if potential_managers.size() > 0:
			wave_manager = potential_managers[0]
			
	# Create or find wave display manager
	create_wave_display_manager()

	# Connect hero signals
	_connect_hero_signals()

	# Update gold display
	update_gold_display()
	
	# Count existing heroes and update UI
	update_hero_count()

	# Start the game
	if wave_manager and wave_manager.has_method("start_game"):
		wave_manager.start_game()

# Count existing heroes and update the hero count
func update_hero_count():
	var heroes = get_tree().get_nodes_in_group("heroes")
	hero_count = heroes.size()
	print("Current hero count: " + str(hero_count) + "/" + str(max_heroes))
	
	# Update hero shop availability based on hero count
	if ui and ui.has_method("update_hero_shop_availability"):
		ui.update_hero_shop_availability(hero_count < max_heroes)

func create_wave_display_manager():
	# Find existing wave display manager
	wave_display_manager = get_node_or_null("WaveDisplayManager")
	if not wave_display_manager:
		# Try to find it in the scene
		var potential_displays = get_tree().get_nodes_in_group("wave_display_manager")
		if potential_displays.size() > 0:
			wave_display_manager = potential_displays[0]
		else:
			# Create a new Control node
			wave_display_manager = Control.new()
			wave_display_manager.name = "WaveDisplayManager"
			
			# Set it to fill the entire screen
			wave_display_manager.anchor_right = 1.0
			wave_display_manager.anchor_bottom = 1.0
			
			# Add the script
			var script = GDScript.new()
			script.source_code = """
extends Control

# Add to group for easy finding
func _ready():
	add_to_group("wave_display_manager")

# Signal connections
signal wave_display_updated

# References
var wave_manager = null
var main_scene = null
var is_paused = false

# Wave information
var current_wave = 1
var total_waves = 15
var enemies_remaining = 0
var total_enemies_in_wave = 0
var time_to_next_wave = 0
var wave_in_progress = false
var countdown_active = false

# UI elements
var wave_info_panel = null
var wave_label = null
var enemy_label = null
var progress_bar = null
var countdown_label = null
var next_wave_button = null

func _ready():
	print("WaveDisplayManager: _ready() called")
	
	# Set up UI elements programmatically
	create_ui_elements()
	
	# Find wave manager
	wave_manager = get_node_or_null("/root/Node2D_main/WaveManager")
	if not wave_manager:
		var potential_managers = get_tree().get_nodes_in_group("wave_manager")
		if potential_managers.size() > 0:
			wave_manager = potential_managers[0]
			print("WaveDisplayManager: Found WaveManager in group")
		else:
			print("WaveDisplayManager: WARNING - WaveManager not found")
	else:
		print("WaveDisplayManager: Found WaveManager at path")
	
	# Find main scene
	main_scene = get_node_or_null("/root/Node2D_main")
	if main_scene:
		print("WaveDisplayManager: Found main scene")
	else:
		print("WaveDisplayManager: WARNING - Main scene not found")
	
	# Connect to wave manager signals
	if wave_manager:
		if wave_manager.has_signal("wave_started"):
			wave_manager.wave_started.connect(_on_wave_started)
			print("WaveDisplayManager: Connected wave_started signal")
		
		if wave_manager.has_signal("wave_completed"):
			wave_manager.wave_completed.connect(_on_wave_completed)
			print("WaveDisplayManager: Connected wave_completed signal")
		
		if wave_manager.has_signal("countdown_tick"):
			wave_manager.countdown_tick.connect(_on_countdown_tick)
			print("WaveDisplayManager: Connected countdown_tick signal")
		
		if wave_manager.has_signal("enemy_killed"):
			wave_manager.enemy_killed.connect(_on_enemy_killed)
			print("WaveDisplayManager: Connected enemy_killed signal")
		
		# Get initial values
		if wave_manager.has_method("get_current_wave"):
			current_wave = wave_manager.get_current_wave()
		
		if wave_manager.has_method("get_total_waves"):
			total_waves = wave_manager.get_total_waves()
		
		if wave_manager.has_method("get_time_to_next_wave"):
			time_to_next_wave = wave_manager.get_time_to_next_wave()
		
		if wave_manager.has_method("is_wave_in_progress"):
			wave_in_progress = wave_manager.is_wave_in_progress()
		
		if wave_manager.has_method("is_countdown_active"):
			countdown_active = wave_manager.is_countdown_active()
		
		if wave_manager.has_method("get_enemies_remaining"):
			enemies_remaining = wave_manager.get_enemies_remaining()
	
	# Initial update
	update_display()
	
	print("WaveDisplayManager: Ready")

func create_ui_elements():
	print("WaveDisplayManager: Creating UI elements")
	
	# Create main panel
	wave_info_panel = Panel.new()
	wave_info_panel.name = "WaveInfoPanel"
	
	# Set up anchoring to center top
	wave_info_panel.anchor_left = 0.5
	wave_info_panel.anchor_right = 0.5
	wave_info_panel.anchor_top = 0.0
	wave_info_panel.anchor_bottom = 0.0
	
	# Set position relative to anchor (center top)
	wave_info_panel.offset_left = -150
	wave_info_panel.offset_top = 10
	wave_info_panel.offset_right = 150
	wave_info_panel.offset_bottom = 110
	
	# Add a visible style to the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray, semi-transparent
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	wave_info_panel.add_theme_stylebox_override("panel", style)
	
	add_child(wave_info_panel)
	
	# Create wave label
	wave_label = Label.new()
	wave_label.name = "WaveLabel"
	wave_label.anchor_left = 0.5
	wave_label.anchor_right = 0.5
	wave_label.offset_left = -100
	wave_label.offset_top = 5
	wave_label.offset_right = 100
	wave_label.offset_bottom = 31
	wave_label.text = "Wave: 1 / 15"
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_info_panel.add_child(wave_label)
	
	# Create enemy label
	enemy_label = Label.new()
	enemy_label.name = "EnemyLabel"
	enemy_label.anchor_left = 0.5
	enemy_label.anchor_top = 0.5
	enemy_label.anchor_right = 0.5
	enemy_label.anchor_bottom = 0.5
	enemy_label.offset_left = -100
	enemy_label.offset_top = -13
	enemy_label.offset_right = 100
	enemy_label.offset_bottom = 13
	enemy_label.text = "Enemies: 0"
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_info_panel.add_child(enemy_label)
	
	# Create progress bar
	progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.anchor_left = 0.5
	progress_bar.anchor_top = 1.0
	progress_bar.anchor_right = 0.5
	progress_bar.anchor_bottom = 1.0
	progress_bar.offset_left = -125
	progress_bar.offset_top = -35
	progress_bar.offset_right = 125
	progress_bar.offset_bottom = -20
	progress_bar.max_value = 100
	progress_bar.step = 1
	progress_bar.value = 0
	progress_bar.show_percentage = false
	wave_info_panel.add_child(progress_bar)
	
	# Create countdown label
	countdown_label = Label.new()
	countdown_label.name = "CountdownLabel"
	countdown_label.anchor_left = 0.5
	countdown_label.anchor_top = 1.0
	countdown_label.anchor_right = 0.5
	countdown_label.anchor_bottom = 1.0
	countdown_label.offset_left = -100
	countdown_label.offset_top = -20
	countdown_label.offset_right = 100
	countdown_label.offset_bottom = 6
	countdown_label.text = "Next wave in: 10s"
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_info_panel.add_child(countdown_label)
	
	# Create next wave button
	next_wave_button = Button.new()
	next_wave_button.name = "NextWaveButton"
	next_wave_button.anchor_left = 0.5
	next_wave_button.anchor_top = 1.0
	next_wave_button.anchor_right = 0.5
	next_wave_button.anchor_bottom = 1.0
	next_wave_button.offset_left = -60
	next_wave_button.offset_top = 10
	next_wave_button.offset_right = 60
	next_wave_button.offset_bottom = 41
	next_wave_button.text = "Start Wave"
	next_wave_button.pressed.connect(_on_next_wave_button_pressed)
	wave_info_panel.add_child(next_wave_button)
	
	print("WaveDisplayManager: UI elements created")

func _process(delta):
	if is_paused:
		return
	
	# Keep the display updated
	update_display()

func update_display():
	# Update wave label
	if wave_label:
		wave_label.text = "Wave: " + str(current_wave) + " / " + str(total_waves)
	
	# Update enemy label
	if enemy_label:
		enemy_label.text = "Enemies: " + str(enemies_remaining)
	
	# Update progress bar
	if progress_bar and total_enemies_in_wave > 0:
		var progress = float(total_enemies_in_wave - enemies_remaining) / float(total_enemies_in_wave)
		progress_bar.value = progress * 100
	
	# Update countdown label and button visibility
	if countdown_label:
		if countdown_active and time_to_next_wave > 0:
			countdown_label.text = "Next wave in: " + str(int(time_to_next_wave)) + "s"
			countdown_label.visible = true
		elif wave_in_progress:
			countdown_label.text = "Wave in progress"
			countdown_label.visible = true
		else:
			countdown_label.visible = false
	
	if next_wave_button:
		next_wave_button.visible = countdown_active and time_to_next_wave > 0
	
	emit_signal("wave_display_updated")

func _on_wave_started(wave_number):
	current_wave = wave_number
	wave_in_progress = true
	countdown_active = false
	
	# Get total enemies in this wave
	if wave_manager and wave_manager.has_method("get_enemies_remaining"):
		enemies_remaining = wave_manager.get_enemies_remaining()
		total_enemies_in_wave = enemies_remaining
	
	print("WaveDisplayManager: Wave " + str(wave_number) + " started with " + str(enemies_remaining) + " enemies")
	update_display()
	check_boss_wave()

func _on_wave_completed(wave_number):
	wave_in_progress = false
	print("WaveDisplayManager: Wave " + str(wave_number) + " completed")
	update_display()

func _on_countdown_tick(time_left):
	time_to_next_wave = time_left
	countdown_active = true
	update_display()

func _on_enemy_killed(enemy):
	if enemies_remaining > 0:
		enemies_remaining -= 1
	update_display()

func _on_next_wave_button_pressed():
	if wave_manager and wave_manager.has_method("skip_countdown"):
		wave_manager.skip_countdown()
		print("WaveDisplayManager: Next wave button pressed")

func set_paused(paused):
	is_paused = paused
	print("WaveDisplayManager: Paused state set to " + str(is_paused))

# Check if current wave is a boss wave and update display accordingly
func check_boss_wave():
	if wave_manager and wave_manager.has_method("is_boss_wave"):
		var is_boss = wave_manager.is_boss_wave()
		if is_boss and wave_info_panel:
			# Highlight panel for boss wave
			var style = wave_info_panel.get_theme_stylebox("panel")
			if style is StyleBoxFlat:
				style.bg_color = Color(0.5, 0.1, 0.1, 0.8)  # Red tint for boss waves
		else:
			# Reset to normal color
			var style = wave_info_panel.get_theme_stylebox("panel")
			if style is StyleBoxFlat:
				style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Normal color
"""
			script.reload()
			wave_display_manager.set_script(script)
			
			add_child(wave_display_manager)


func _process(delta):
	# Handle hero placement preview
	if placing_hero and hero_preview:
		hero_preview.global_position = get_global_mouse_position()

	# Handle escape key to cancel actions
	if Input.is_action_just_pressed("ui_cancel"):
		_cancel_current_action()

func _input(event):
	# Handle hero placement
	if placing_hero and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_place_hero(get_global_mouse_position())

	# Handle hero movement
	if moving_hero and selected_hero and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_move_hero(get_global_mouse_position())

	# Handle hero selection
	if not placing_hero and not moving_hero and not placing_barrier and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_select_hero_at_mouse()

	# Handle right-click to cancel actions
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_current_action()

# Signal handlers
func _on_hero_purchase_requested(hero_type, position):
	# Check if we have enough gold
	var hero_data = {}
	if ui and ui.has_method("get_hero_data"):
		hero_data = ui.get_hero_data(hero_type)
	elif hero_shop and hero_shop.has_method("get_hero_data"):
		hero_data = hero_shop.get_hero_data(hero_type)
	else:
		return

	var cost = hero_data.get("cost", 200)

	# Check if we have enough gold and haven't reached the hero limit
	if gold < cost or hero_count >= max_heroes:
		print("Cannot purchase hero: " + ("Not enough gold" if gold < cost else "Hero limit reached"))
		return

	# Start hero placement
	start_hero_placement(hero_type)

func start_hero_placement(hero_type):
	# Cancel any current action
	_cancel_current_action()

	placing_hero = true
	placing_hero_type = hero_type

	# Show grid for placement
	if grid_system:
		grid_system.set_buying_hero(true)

	# Create hero preview
	_create_hero_preview(hero_type)

func _create_hero_preview(hero_type):
	# Get hero data
	var hero_data = {}
	if ui and ui.has_method("get_hero_data"):
		hero_data = ui.get_hero_data(hero_type)
	elif hero_shop and hero_shop.has_method("hero_data"):
		hero_data = hero_shop.get_hero_data(hero_type)
	else:
		return
		
	var scene_path = hero_data.get("scene", "")

	if scene_path.is_empty():
		return

	# Load hero scene
	var hero_scene = load(scene_path)
	if not hero_scene:
		return

	# Create preview
	hero_preview = hero_scene.instantiate()
	hero_preview.modulate = Color(1, 1, 1, 0.5)  # Make it semi-transparent
	add_child(hero_preview)


func _try_place_hero(position):
	if not grid_system:
		return

	# Convert to grid position
	var grid_pos = grid_system.world_to_grid(position)

	# Check if position is in green zone
	if not grid_system.is_in_green_zone(grid_pos):
		return

	# Check if cell is empty
	if not grid_system.is_cell_empty(grid_pos):
		return

	# Get hero data
	var hero_data = {}
	if ui and ui.has_method("get_hero_data"):
		hero_data = ui.get_hero_data(placing_hero_type)
	elif hero_shop and hero_shop.has_method("get_hero_data"):
		hero_data = hero_shop.get_hero_data(placing_hero_type)
	else:
		return
		
	var cost = hero_data.get("cost", 200)
	var scene_path = hero_data.get("scene", "")

	if scene_path.is_empty():
		return

	# Load hero scene
	var hero_scene = load(scene_path)
	if not hero_scene:
		return

	# Deduct gold
	gold -= cost
	update_gold_display()

	# Remove preview
	if hero_preview:
		hero_preview.queue_free()
		hero_preview = null

	# Create actual hero
	var hero = hero_scene.instantiate()
	hero.global_position = grid_system.grid_to_world(grid_pos)
	add_child(hero)

	# If game is paused, pause the new hero too
	if game_paused and hero.has_method("set_paused"):
		hero.set_paused(true)

	# Connect hero signals
	if hero.has_signal("selected"):
		hero.selected.connect(_on_hero_selected)

	if hero.has_signal("hero_killed"):
		hero.hero_killed.connect(_on_hero_killed)

	# Increment hero count and update UI
	hero_count += 1
	print("Hero placed. New count: " + str(hero_count) + "/" + str(max_heroes))
	
	# Update hero shop availability
	if ui and ui.has_method("update_hero_shop_availability"):
		ui.update_hero_shop_availability(hero_count < max_heroes)

	# End placement mode
	placing_hero = false
	placing_hero_type = ""

	# Hide grid
	if grid_system:
		grid_system.set_buying_hero(false)

func _on_move_button_pressed(hero = null):
	# Use the provided hero or the selected hero
	var hero_to_move = hero if hero else selected_hero
	
	if not hero_to_move or not is_instance_valid(hero_to_move):
		return
	
	# Start hero movement
	moving_hero = true
	selected_hero = hero_to_move
	
	# Show grid for movement
	if grid_system:
		grid_system.set_moving_hero(true)
	
	# Hide hero panel
	if ui:
		ui.show_hero_panel(Vector2.ZERO, false)
	

func _try_move_hero(position):
	if not selected_hero or not is_instance_valid(selected_hero) or not grid_system:
		moving_hero = false
		if grid_system:
			grid_system.set_moving_hero(false)
		return
	
	# Convert to grid position
	var grid_pos = grid_system.world_to_grid(position)
	
	# Check if position is in green zone
	if not grid_system.is_in_green_zone(grid_pos):
		return
	
	# Check if cell is empty
	if not grid_system.is_cell_empty(grid_pos):
		return
	
	# Set hero's move target
	if selected_hero.has_method("set_move_target"):
		selected_hero.set_move_target(grid_system.grid_to_world(grid_pos))

	# End movement mode
	moving_hero = false
	
	# Hide grid
	if grid_system:
		grid_system.set_moving_hero(false)
	
	# Deselect hero
	_deselect_hero()

func _on_sell_button_pressed(hero = null):
	# Use the provided hero or the selected hero
	var hero_to_sell = hero if hero else selected_hero

	if not hero_to_sell or not is_instance_valid(hero_to_sell):
		return

	# Get sell value
	var sell_value = 0
	if hero_to_sell.has_method("get_sell_value"):
		sell_value = hero_to_sell.get_sell_value()
	else:
		sell_value = 100  # Default value

	# Get grid position before removing the hero
	var hero_grid_pos = Vector2(-1, -1)
	if hero_to_sell.has_method("get_grid_position"):
		hero_grid_pos = hero_to_sell.get_grid_position()
	
	# Add gold
	gold += sell_value
	update_gold_display()

	# Hide hero panel before removing the hero
	if ui:
		ui.show_hero_panel(Vector2.ZERO, false)

	# Clear selected hero if it was the one sold
	if hero_to_sell == selected_hero:
		selected_hero = null

	# Explicitly clear the grid cell
	if grid_system and hero_grid_pos != Vector2(-1, -1):
		grid_system.unregister_hero(hero_grid_pos)
		grid_system.set_cell_empty(hero_grid_pos)

	# Remove hero
	hero_to_sell.queue_free()
	
	# Decrement hero count and update UI
	hero_count -= 1
	print("Hero sold. New count: " + str(hero_count) + "/" + str(max_heroes))
	
	# Update hero shop availability
	if ui and ui.has_method("update_hero_shop_availability"):
		ui.update_hero_shop_availability(hero_count < max_heroes)

func _on_barrier_button_pressed():
	# Toggle barrier placement mode
	placing_barrier = !placing_barrier

	# Update button text
	if barrier_placer:
		if placing_barrier:
			barrier_placer.start_placing_barriers()
			
			# Update button text if it exists
			var barrier_button = get_node_or_null("UI/Control/BarrierButton")
			if barrier_button:
				barrier_button.text = "Exit Build Mode"
		else:
			barrier_placer.exit_placing_mode()
			
			# Update button text if it exists
			var barrier_button = get_node_or_null("UI/Control/BarrierButton")
			if barrier_button:
				barrier_button.text = "Place Barriers"

func _try_select_hero_at_mouse():
	var heroes = get_tree().get_nodes_in_group("heroes")
	
	var mouse_pos = get_global_mouse_position()
	
	# Check if we're clicking on the currently selected hero
	if selected_hero and is_instance_valid(selected_hero):
		if selected_hero.has_method("is_mouse_over") and selected_hero.is_mouse_over():
			_deselect_hero()
			return
	
	# Deselect current hero
	if selected_hero:
		_deselect_hero()
	
	# Check if mouse is over a hero
	for hero in heroes:
		if is_instance_valid(hero):  # Add check to ensure hero is valid
			if hero.has_method("is_mouse_over"):
				if hero.is_mouse_over():
					_select_hero(hero)
					return


func _on_hero_selected(hero):
	if not is_instance_valid(hero):
		return
		
	# Deselect current hero if different
	if selected_hero and selected_hero != hero:
		_deselect_hero()

	# Select new hero
	_select_hero(hero)

func _select_hero(hero):
	if not is_instance_valid(hero):
		return
		
	selected_hero = hero

	# Set hero as selected
	if hero.has_method("set_selected"):
		hero.set_selected(true)

	# Show hero panel
	if ui:
		ui.show_hero_panel(hero.global_position, true, hero)


func _deselect_hero():
	if not selected_hero or not is_instance_valid(selected_hero):
		selected_hero = null
		return

	# Set hero as not selected
	if selected_hero.has_method("set_selected"):
		selected_hero.set_selected(false)

	# Hide hero panel
	if ui:
		ui.show_hero_panel(Vector2.ZERO, false)

	selected_hero = null

func _on_hero_killed(hero):
	# If this was the selected hero, clear selection
	if hero == selected_hero:
		selected_hero = null
		
		# Hide hero panel
		if ui:
			ui.show_hero_panel(Vector2.ZERO, false)
	
	# Decrement hero count and update UI
	hero_count -= 1
	print("Hero died. New count: " + str(hero_count) + "/" + str(max_heroes))
	
	# Update hero shop availability
	if ui and ui.has_method("update_hero_shop_availability"):
		ui.update_hero_shop_availability(hero_count < max_heroes)

func _cancel_current_action():
	# Cancel hero placement
	if placing_hero:
		placing_hero = false
		placing_hero_type = ""
		
		# Remove preview
		if hero_preview:
			hero_preview.queue_free()
			hero_preview = null
		
		# Hide grid
		if grid_system:
			grid_system.set_buying_hero(false)

	# Cancel hero movement
	if moving_hero:
		moving_hero = false
		
		# Hide grid
		if grid_system:
			grid_system.set_moving_hero(false)

	# Cancel barrier placement
	if placing_barrier and barrier_placer:
		placing_barrier = false
		barrier_placer.exit_placing_mode()
		
		# Update button text if it exists
		var barrier_button = get_node_or_null("UI/Control/BarrierButton")
		if barrier_button:
			barrier_button.text = "Place Barriers"

	# Deselect hero
	if selected_hero:
		_deselect_hero()

func _connect_hero_signals():
	# Connect signals for existing heroes
	var heroes = get_tree().get_nodes_in_group("heroes")
	for hero in heroes:
		if is_instance_valid(hero):
			if hero.has_signal("selected") and not hero.selected.is_connected(_on_hero_selected):
				hero.selected.connect(_on_hero_selected)
			
			if hero.has_signal("hero_killed") and not hero.hero_killed.is_connected(_on_hero_killed):
				hero.hero_killed.connect(_on_hero_killed)

func update_gold_display():
	if ui and ui.has_method("update_gold_display"):
		ui.update_gold_display(gold)
		
		if ui.has_method("update_hero_shop_buttons"):
			ui.update_hero_shop_buttons(gold)
	else:
		# Try to find UI with different paths
		ui = get_node_or_null("UI")
		if not ui:
			ui = get_node_or_null("ui")
		if not ui:
			ui = get_node_or_null("FixedUIContainer")
		
		if ui and ui.has_method("update_gold_display"):
			ui.update_gold_display(gold)
			
			if ui.has_method("update_hero_shop_buttons"):
				ui.update_hero_shop_buttons(gold)

func _on_pause_button_toggled(is_paused: bool):
	# Set game pause state
	game_paused = is_paused

	# Notify wave manager
	if wave_manager and wave_manager.has_method("set_paused"):
		wave_manager.set_paused(is_paused)
	
	# Notify wave display manager
	if wave_display_manager and wave_display_manager.has_method("set_paused"):
		wave_display_manager.set_paused(is_paused)

	# Notify all heroes
	var heroes = get_tree().get_nodes_in_group("heroes")
	for hero in heroes:
		if is_instance_valid(hero) and hero.has_method("set_paused"):
			hero.set_paused(is_paused)
		elif is_instance_valid(hero) and "is_paused" in hero:
			hero.is_paused = is_paused

	# Notify all enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("set_paused"):
			enemy.set_paused(is_paused)
		elif is_instance_valid(enemy) and "is_paused" in enemy:
			enemy.is_paused = is_paused
		else:
			# Fallback for enemies without set_paused method
			enemy.set_process(not is_paused)
			enemy.set_physics_process(not is_paused)
			
			# Find and pause all animation players in the enemy
			for child in enemy.get_children():
				if child is AnimationPlayer:
					if is_paused:
						child.pause()
					else:
						child.play()

	# Pause all projectiles
	var projectiles = get_tree().get_nodes_in_group("projectiles")
	for projectile in projectiles:
		if is_instance_valid(projectile):
			if projectile.has_method("set_paused"):
				projectile.set_paused(is_paused)
			else:
				projectile.set_process(not is_paused)
				projectile.set_physics_process(not is_paused)
	
	# Pause all heal projectiles
	var heal_projectiles = []
	for node in get_tree().get_nodes_in_group("heal_projectiles"):
		heal_projectiles.append(node)
	if heal_projectiles.size() == 0:
		# Try to find them by class name if they're not in a group
		for node in get_tree().get_nodes_in_group("projectiles"):
			if "heal" in node.name.to_lower():
				heal_projectiles.append(node)
	
	for projectile in heal_projectiles:
		if is_instance_valid(projectile):
			if projectile.has_method("set_paused"):
				projectile.set_paused(is_paused)
			else:
				projectile.set_process(not is_paused)
				projectile.set_physics_process(not is_paused)
	
	# Find and pause all animation players in the scene
	var animation_players = []
	_find_all_animation_players(self, animation_players)
	
	for anim_player in animation_players:
		if is_instance_valid(anim_player):
			if is_paused:
				anim_player.pause()
			else:
				anim_player.play()


func exit_barrier_mode():
	# This function is called from BarrierPlacer when exiting placement mode
	placing_barrier = false
	
	# Update button text if it exists
	var barrier_button = get_node_or_null("UI/Control/BarrierButton")
	if barrier_button:
		barrier_button.text = "Place Barriers"
	

func game_over():
	# Only trigger game over once
	if game_over_triggered:
		return
		
	print("xzxxxxxxxxxx")
	ui.show_game_over()
	print("xzxxxxxxxxxx")
	$FixedUIContainer/GameOver.visible=true
	game_over_triggered = true

	# Stop the game
	game_paused = true
	
	# Notify all heroes
	var heroes = get_tree().get_nodes_in_group("heroes")
	for hero in heroes:
		if is_instance_valid(hero) and hero.has_method("set_paused"):
			hero.set_paused(true)
		elif is_instance_valid(hero) and "is_paused" in hero:
			hero.is_paused = true
	
	# Notify all enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("set_paused"):
			enemy.set_paused(true)
		elif is_instance_valid(enemy) and "is_paused" in enemy:
			enemy.is_paused = true
		else:
			# Fallback for enemies without set_paused method
			enemy.set_process(false)
			enemy.set_physics_process(false)

	# Notify wave manager
	if wave_manager and wave_manager.has_method("set_paused"):
		wave_manager.set_paused(true)
		
	# Notify wave display manager
	if wave_display_manager and wave_display_manager.has_method("set_paused"):
		wave_display_manager.set_paused(true)


func _find_all_animation_players(node: Node, result: Array):
	if node is AnimationPlayer:
		result.append(node)
	
	for child in node.get_children():
		_find_all_animation_players(child, result)

func zoom_in():
	# Try to find the camera and zoom in directly
	var camera = get_viewport().get_camera_2d()
	if camera:
		# Check if camera has zoom_in method (from our controller)
		if camera.has_method("zoom_in"):
			camera.zoom_in()
		else:
			# Zoom in by decreasing the zoom factor (making objects appear larger)
			camera.zoom = camera.zoom * 1.2  # Increase by 20%


func zoom_out():
	# Try to find the camera and zoom out directly
	var camera = get_viewport().get_camera_2d()
	if camera:
		# Check if camera has zoom_out method (from our controller)
		if camera.has_method("zoom_out"):
			camera.zoom_out()
		else:
			# Zoom out by increasing the zoom factor (making objects appear smaller)
			camera.zoom = camera.zoom * 0.8  # Decrease by 20%


func _on_match_ended() -> void:
	get_tree().change_scene_to_file("res://interface/main_menu.tscn") 

func _on_quit_game():
	get_tree().change_scene_to_file("res://interface/main_menu.tscn")
