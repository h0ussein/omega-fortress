extends Node2D

# References
@onready var grid_system = $"../GridSystem"
@onready var game_map = $".."

# Hero scenes
var hero_scenes = {
	"mage": preload("res://scenes/red_wizard_woman.tscn"),

}

# State
var selected_hero = null
var heroes = []
var is_placing_hero = false
var is_moving_hero = false
var current_hero_type = "mage"  # Default hero type to place

func _ready():
	print("HeroManager ready")
	
	# Check if hero scenes exist and load defaults if not
	for hero_type in hero_scenes.keys():
		if not ResourceLoader.exists(hero_scenes[hero_type].resource_path):
			print("WARNING: Hero scene not found: ", hero_scenes[hero_type].resource_path)
			# Try to find a default scene
			var default_path = "res://scenes/hero_base.tscn"
			if ResourceLoader.exists(default_path):
				hero_scenes[hero_type] = load(default_path)
				print("Loaded default hero scene for ", hero_type)
			else:
				print("ERROR: No default hero scene found!")
	
	print("Available hero types: ", hero_scenes.keys())

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_placing_hero:
				place_hero_at_mouse()
			elif is_moving_hero and selected_hero:
				move_selected_hero_to_mouse()

func place_hero_at_mouse():
	var mouse_pos = get_global_mouse_position()
	var grid_pos = grid_system.world_to_grid(mouse_pos)
	
	if grid_system.is_valid_placement_cell(grid_pos):
		var world_pos = grid_system.grid_to_world(grid_pos)
		spawn_hero(current_hero_type, world_pos, grid_pos)
		is_placing_hero = false
		print("Hero placed at grid position: ", grid_pos)
	else:
		print("Cannot place hero at grid position: ", grid_pos)

func spawn_hero(hero_type: String, world_pos: Vector2, grid_pos: Vector2i):
	if not hero_scenes.has(hero_type):
		print("ERROR: Unknown hero type: ", hero_type)
		return null
		
	var hero = hero_scenes[hero_type].instantiate()
	hero.position = world_pos
	
	# Set grid position if the property exists
	if "grid_position" in hero:
		hero.grid_position = grid_pos
	
	# Set grid system reference if the property exists
	if "grid_system" in hero:
		hero.grid_system = grid_system
	
	# Make sure the hero has input_pickable enabled
	hero.input_pickable = true
	
	# Connect signals if they exist
	if hero.has_signal("selected"):
		hero.selected.connect(_on_hero_selected)
	
	if hero.has_signal("hero_killed"):
		hero.hero_killed.connect(_on_hero_killed)
	
	add_child(hero)
	heroes.append(hero)
	
	# Register with grid
	grid_system.register_hero(hero, grid_pos)
	
	print("Spawned hero of type: ", hero_type)
	return hero

func move_selected_hero_to_mouse():
	if not selected_hero:
		return
		
	var mouse_pos = get_global_mouse_position()
	var grid_pos = grid_system.world_to_grid(mouse_pos)
	
	if grid_system.is_valid_movement_cell(grid_pos):
		# Check if the hero has the set_move_target method
		if selected_hero.has_method("set_move_target"):
			selected_hero.set_move_target(grid_system.grid_to_world(grid_pos))
		else:
			# Fallback to direct position setting
			selected_hero.position = grid_system.grid_to_world(grid_pos)
			if "grid_position" in selected_hero:
				selected_hero.grid_position = grid_pos
			grid_system.update_hero_position(selected_hero, grid_pos)
		
		is_moving_hero = false
		
		# Hide movement grid
		grid_system.hide_movement_grid()
		
		print("Moving hero to grid position: ", grid_pos)
	else:
		print("Cannot move hero to grid position: ", grid_pos)

func _on_hero_selected(hero):
	# Deselect previous hero
	if selected_hero and selected_hero != hero:
		if selected_hero.has_method("set_selected"):
			selected_hero.set_selected(false)
	
	selected_hero = hero
	
	if hero.has_method("set_selected"):
		hero.set_selected(true)
	
	print("Hero selected: ", hero.name)

func _on_hero_killed(hero):
	if selected_hero == hero:
		selected_hero = null
	
	heroes.erase(hero)
	print("Hero killed: ", hero.name)

# Called from main scene when place button is pressed
func start_place_mode(hero_type: String = "mage"):
	if not hero_scenes.has(hero_type):
		print("WARNING: Unknown hero type for placement: ", hero_type)
		hero_type = hero_scenes.keys()[0]  # Use first available type
	
	current_hero_type = hero_type
	is_placing_hero = true
	print("Place mode started for hero type: ", hero_type)

# Called from hero when move button is pressed
func start_move_mode_for_hero(hero):
	if hero:
		selected_hero = hero
		is_moving_hero = true
		
		# Get move speed if available
		var move_speed = 100.0  # Default
		if "move_speed" in hero:
			move_speed = hero.move_speed
		
		# Show movement grid
		grid_system.show_movement_grid(hero.grid_position, move_speed)
		
		print("Move mode started for hero: ", hero.name)
