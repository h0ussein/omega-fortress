extends Node

# We'll use more flexible node finding methods
var hbox_container: HBoxContainer
var map1: Control
var map2: Control

func _ready():
	# Wait one frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Find the nodes using more robust methods
	hbox_container = find_hbox_container()
	if hbox_container:
		map1 = hbox_container.get_node_or_null("map1")
		map2 = hbox_container.get_node_or_null("map2")
	
	# Only proceed if we found all the nodes
	if hbox_container and map1 and map2:
		# Connect to the window resize signal
		get_viewport().size_changed.connect(_on_viewport_size_changed)
		
		# Initial setup
		_on_viewport_size_changed()
	else:
		push_error("Could not find all required nodes. Check the scene structure.")
		print("HBoxContainer found: ", hbox_container != null)
		print("map1 found: ", map1 != null)
		print("map2 found: ", map2 != null)

# Helper function to find the HBoxContainer regardless of where the script is attached
func find_hbox_container() -> HBoxContainer:
	# Try different approaches to find the HBoxContainer
	
	# 1. Try direct path if we're at the scene root
	var container = get_node_or_null("map/HBoxContainer")
	if container:
		return container
		
	# 2. Try if we're attached to the "map" node
	container = get_node_or_null("HBoxContainer")
	if container:
		return container
		
	# 3. Try searching the scene tree
	var map_node = find_node_by_name(get_tree().root, "map")
	if map_node:
		container = map_node.get_node_or_null("HBoxContainer")
		if container:
			return container
			
	# 4. Last resort: find any HBoxContainer in the scene
	return find_node_by_type(get_tree().root, HBoxContainer) as HBoxContainer

# Helper function to find a node by name in the scene tree
func find_node_by_name(node: Node, name: String) -> Node:
	if node.name == name:
		return node
		
	for child in node.get_children():
		var found = find_node_by_name(child, name)
		if found:
			return found
			
	return null

# Helper function to find a node by type in the scene tree
func find_node_by_type(node: Node, type) -> Node:
		
	for child in node.get_children():
		var found = find_node_by_type(child, type)
		if found:
			return found
			
	return null

func _on_viewport_size_changed():
	if !hbox_container or !map1 or !map2:
		return
		
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Configure the HBoxContainer
	hbox_container.size_flags_horizontal = Control.SIZE_FILL
	hbox_container.size_flags_vertical = Control.SIZE_FILL
	
	# Set minimum size for maps
	var min_map_width = 200  # Adjust as needed
	
	# Configure map1 and map2
	map1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map1.custom_minimum_size = Vector2(min_map_width, 0)
	
	map2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map2.custom_minimum_size = Vector2(min_map_width, 0)
	
	# Optional: Adjust spacing between maps
	hbox_container.add_theme_constant_override("separation", 10)
