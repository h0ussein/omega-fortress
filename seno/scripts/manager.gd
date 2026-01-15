extends Node2D

var selected_hero: CharacterBody2D = null
@onready var control_panel = $wizard/HeroPanel

func _ready():
	# Find all heroes in the scene and connect their signals
	connect_all_heroes()
	
	# Hide the panel initially
	if control_panel:
		control_panel.visible = false

# Connect to all heroes in the scene
func connect_all_heroes():
	# Wait until the scene is fully loaded
	await get_tree().process_frame
	
	# Find all heroes in the scene
	var heroes = get_tree().get_nodes_in_group("heroes")
	for hero in heroes:
		if hero.has_signal("selected"):
			if not hero.selected.is_connected(_on_hero_selected):
				hero.selected.connect(_on_hero_selected)
				print("Connected to hero: ", hero.name)

func _on_hero_selected(hero):
	print("Hero was selected: ", hero.name)
	
	# Deselect previous hero if any
	if selected_hero and selected_hero != hero:
		selected_hero.set_selected(false)
	
	# Set new selected hero
	selected_hero = hero
	
	# Show and position the control panel
	if control_panel:
		control_panel.visible = true
		control_panel.global_position = hero.global_position + Vector2(0, -50)

# Handle clicks on the background to deselect heroes
func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if we clicked on empty space
		var clicked_on_ui = false
		# Add logic to check if clicked on UI elements
		
		if not clicked_on_ui and selected_hero:
			selected_hero.set_selected(false)
			selected_hero = null
			if control_panel:
				control_panel.visible = false
