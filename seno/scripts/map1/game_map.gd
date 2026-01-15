extends Node2D

# Signals
signal build_mode_changed(enabled)
signal gold_changed(amount)

# References
@onready var base = $Base
@onready var grid_system = $GridSystem
@onready var barrier_system = $GridSystem/BarrierSystem
@onready var hero_manager = $HeroManager
@onready var hero_shop = $UI/HeroShop

# State
var build_mode = false
var button_pressed_this_frame = false
var player_gold = 500  # Starting gold amount

# Create a node to hold all barriers
var barriers_container

func _ready():
	# Create a container for barriers
	barriers_container = Node2D.new()
	barriers_container.name = "BarriersContainer"
	add_child(barriers_container)
	
	# Get the base node from the group if it exists
	var base_nodes = get_tree().get_nodes_in_group("base")
	if base_nodes.size() > 0:
		base = base_nodes[0]
		print("Found base in 'base' group: ", base.name)
	elif base == null:
		print("WARNING: Base reference is null, using default position")
		base = Node2D.new()
		base.position = Vector2(0, 0)

	# Center grid on base position
	grid_system.center_on_base(base.global_position)
	print("GameMap initialized, grid centered on base at ", base.global_position)

	# Make sure grid is initially invisible and build mode is off
	grid_system.visible = false
	build_mode = false
	print("Grid initial visibility: ", grid_system.visible)
	print("Initial build mode: ", build_mode)

	# Fix UI elements to screen positions
	fix_ui_elements_to_screen()

	# Connect UI signals
	var build_button = $UI/BuildButton
	if build_button:
		build_button.pressed.connect(_on_build_button_pressed)
		print("Build button connected")
	else:
		print("BuildButton not found")
		
	# Connect to HeroShop
	if hero_shop:
		hero_shop.hero_purchase_requested.connect(_on_hero_purchase_requested)
		hero_shop.hero_drag_started.connect(_on_hero_drag_started)
		hero_shop.hero_drag_ended.connect(_on_hero_drag_ended)
		hero_shop.update_button_states(player_gold)
		print("HeroShop connected")
	else:
		print("HeroShop not found")

	# Connect barrier count signal to UI
	barrier_system.barrier_count_changed.connect(_on_barrier_count_changed)
	
	# Initial gold update
	emit_signal("gold_changed", player_gold)

# Fix UI elements to specific screen positions
func fix_ui_elements_to_screen():
	# Get the UI CanvasLayer if it exists
	var ui_canvas = get_node_or_null("UI")
	if not ui_canvas:
		print("UI CanvasLayer not found")
		return
	
	# Fix hero shop to bottom of screen

	
	# Fix build button to top-left corner
	var build_button = ui_canvas.get_node_or_null("BuildButton")
	if build_button:
		if build_button is Control:
			build_button.anchor_left = 0
			build_button.anchor_top = 0
			build_button.anchor_right = 0
			build_button.anchor_bottom = 0
			build_button.offset_left = 20
			build_button.offset_top = 20
			build_button.offset_right = 120
			build_button.offset_bottom = 60
			print("Fixed build button to top-left corner")
	
	# Fix game HUD to top of screen
	var game_hud = ui_canvas.get_node_or_null("GameHUD")
	if game_hud:
		if game_hud is Control:
			game_hud.anchor_left = 0
			game_hud.anchor_top = 0
			game_hud.anchor_right = 1
			game_hud.anchor_bottom = 0
			game_hud.offset_left = 130
			game_hud.offset_top = 20
			game_hud.offset_right = -20
			game_hud.offset_bottom = 60
			print("Fixed game HUD to top of screen")
	
	print("UI elements fixed to screen positions")

func _on_hero_drag_started():
	# Show grid when dragging a hero
	grid_system.visible = true
	print("Hero drag started, showing grid")

func _on_hero_drag_ended():
	# Hide grid when drag ends
	if not build_mode:
		grid_system.visible = false
	print("Hero drag ended, hiding grid")

func _on_build_button_pressed():
	# Prevent multiple toggles in the same frame
	if button_pressed_this_frame:
		return

	button_pressed_this_frame = true

	# Use a timer to reset the flag after a short delay
	var timer = get_tree().create_timer(0.2)
	timer.timeout.connect(func(): button_pressed_this_frame = false)

	# Toggle build mode (invert the current state)
	build_mode = !build_mode

	# Set grid visibility to match build mode
	grid_system.visible = build_mode

	print("Build button pressed, build mode: ", build_mode)
	print("Grid visibility: ", grid_system.visible)

	# Emit signal
	emit_signal("build_mode_changed", build_mode)

func _on_hero_purchase_requested(hero_type, position):
	print("Hero purchase requested: " + hero_type + " at position: " + str(position))
	
	# Convert world position to grid position
	var grid_pos = grid_system.world_to_grid(position)
	
	# Check if position is valid for placement
	if grid_system.is_valid_placement_cell(grid_pos):
		# Get hero data from shop
		var hero_data = hero_shop.get_hero_data(hero_type)
		var cost = hero_data["cost"]
		
		# Check if player has enough gold
		if player_gold >= cost:
			# Deduct gold
			player_gold -= cost
			emit_signal("gold_changed", player_gold)
			
			# Update shop button states
			hero_shop.update_button_states(player_gold)
			
			# Place hero
			var world_pos = grid_system.grid_to_world(grid_pos)
			var hero = hero_manager.spawn_hero(hero_type, world_pos, grid_pos)
			
			# Set hero properties from hero data if needed
			if hero and hero_data.has("name"):
				hero.hero_type = hero_type
				if "description" in hero_data:
					hero.description = hero_data["description"]
			
			print("Hero placed at grid position: ", grid_pos)
		else:
			print("Not enough gold to purchase hero")
	else:
		print("Cannot place hero at invalid position: ", grid_pos)

func _on_move_button_pressed():
	# This is called from the UI, not from the hero panel
	if hero_manager.selected_hero:
		# Show grid if not already visible
		if not grid_system.visible:
			grid_system.visible = true
			
		# Start hero move mode
		hero_manager.start_move_mode_for_hero(hero_manager.selected_hero)
		print("Move button pressed")
	else:
		print("No hero selected to move")

func _on_sell_button_pressed():
	# Handle selling a hero
	if hero_manager.selected_hero:
		var hero = hero_manager.selected_hero
		var sell_value = hero.get_sell_value()
		
		# Add gold to player
		player_gold += sell_value
		emit_signal("gold_changed", player_gold)
		
		# Update shop button states
		hero_shop.update_button_states(player_gold)
		
		# Kill the hero
		hero.die()
		print("Hero sold for: ", sell_value)
	else:
		print("No hero selected to sell")

func _on_barrier_count_changed(count):
	var barriers_label = $UI/GameHUD/ResourcePanel/BarriersLabel
	if barriers_label:
		barriers_label.text = str(count)
	else:
		print("BarriersLabel not found")

# Called when a wave is completed
func _on_wave_completed(wave_number):
	# Add more barriers after each wave
	var new_barriers = 5  # Add 5 barriers per wave
	barrier_system.add_barriers(new_barriers)
	
	# Add gold reward
	var gold_reward = 100 + (wave_number * 50)  # Increase reward with each wave
	player_gold += gold_reward
	emit_signal("gold_changed", player_gold)
	
	# Update shop button states
	hero_shop.update_button_states(player_gold)
	
	print("Wave ", wave_number, " completed, added ", new_barriers, " barriers and ", gold_reward, " gold")

# Get current player gold
func get_player_gold():
	return player_gold

# Add gold to player
func add_gold(amount):
	player_gold += amount
	emit_signal("gold_changed", player_gold)
	hero_shop.update_button_states(player_gold)
	print("Added ", amount, " gold. New total: ", player_gold)
	return player_gold

# Deduct gold from player
func deduct_gold(amount):
	if player_gold >= amount:
		player_gold -= amount
		emit_signal("gold_changed", player_gold)
		hero_shop.update_button_states(player_gold)
		print("Deducted ", amount, " gold. New total: ", player_gold)
		return true
	else:
		print("Not enough gold to deduct ", amount, ". Current gold: ", player_gold)
		return false
