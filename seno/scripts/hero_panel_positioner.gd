extends Node

# This script ensures the hero panel stays fixed to the hero when zooming

var ui_container = null
var tracked_hero = null
var last_zoom = Vector2(1, 1)
var last_camera_position = Vector2.ZERO
var panel_offset = Vector2(0, -120)  # Default offset above hero

func _ready():
	# Find UI container - try both possible paths
	ui_container = get_node_or_null("/root/Node2D_main/FixedUIContainer")
	if not ui_container:
		ui_container = get_node_or_null("/root/Node2D_main/ui")
		if not ui_container:
			print("HeroPanelPositioner: ERROR - UI container not found")
			queue_free()
			return
	
	# Get initial camera state
	var camera = get_viewport().get_camera_2d()
	if camera:
		last_zoom = camera.zoom
		last_camera_position = camera.global_position
	
	print("HeroPanelPositioner: Ready")

func _process(delta):
	# Check if UI container exists
	if not ui_container:
		return
	
	# Get tracked hero from UI container
	if "tracked_hero" in ui_container:
		tracked_hero = ui_container.tracked_hero
	
	# Check if hero panel exists
	var hero_panel = null
	if ui_container.has_node("HeroPanel"):
		hero_panel = ui_container.get_node("HeroPanel")
	else:
		return
	
	# Check if tracked hero exists and is valid
	if not tracked_hero or not is_instance_valid(tracked_hero):
		return
	
	# Get camera
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	# Check if zoom or camera position has changed
	if camera.zoom != last_zoom or camera.global_position != last_camera_position:
		last_zoom = camera.zoom
		last_camera_position = camera.global_position
		update_panel_position(hero_panel, tracked_hero, camera)
	
	# Always update panel position to ensure it follows the hero
	update_panel_position(hero_panel, tracked_hero, camera)

func update_panel_position(panel, hero, camera):
	if not panel or not hero or not camera:
		return
	
	# Get hero's world position
	var hero_world_pos = hero.global_position
	
	# Convert to screen coordinates using viewport transform
	var viewport = get_viewport()
	var screen_transform = viewport.get_canvas_transform()
	var hero_screen_pos = screen_transform * hero_world_pos
	
	# Position panel above hero, centered horizontally
	var panel_width = panel.size.x
	var panel_height = panel.size.y
	
	# Calculate position with offset that accounts for zoom
	var offset_y = panel_offset.y / camera.zoom.y  # Adjust vertical offset based on zoom
	var offset_x = panel_offset.x / camera.zoom.x  # Adjust horizontal offset based on zoom
	
	panel.global_position = Vector2(
		hero_screen_pos.x - panel_width / 2 + offset_x,
		hero_screen_pos.y + offset_y
	)
	
	# Ensure panel stays within screen bounds
	var viewport_size = viewport.get_visible_rect().size
	if panel.global_position.x < 10:
		panel.global_position.x = 10
	elif panel.global_position.x + panel_width > viewport_size.x - 10:
		panel.global_position.x = viewport_size.x - panel_width - 10
	
	if panel.global_position.y < 10:
		panel.global_position.y = 10
	elif panel.global_position.y + panel_height > viewport_size.y - 10:
		panel.global_position.y = viewport_size.y - panel_height - 10
	
	# Debug output
	# print("HeroPanelPositioner: Updated panel position to " + str(panel.global_position) + " for hero at " + str(hero_world_pos))
