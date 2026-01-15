extends Node

# Add this script to your main scene to help with debugging

func _ready():
	print("Debug Helper: Ready")
	
	# Print the scene tree to help with debugging
	print_scene_tree()
	
	# Print all resources in the project
	print_resources()

func print_scene_tree():
	print("\n--- SCENE TREE ---")
	_print_node(get_tree().root, 0)
	print("--- END SCENE TREE ---\n")

func _print_node(node, indent):
	var indent_str = ""
	for i in range(indent):
		indent_str += "  "
	
	print(indent_str + node.name + " (" + node.get_class() + ")")
	
	for child in node.get_children():
		_print_node(child, indent + 1)

func print_resources():
	print("\n--- CHECKING RESOURCES ---")
	
	# Check for hero scenes
	var hero_paths = [
		"res://heroes/mage.tscn",
		"res://mage.tscn",
		"res://scenes/heroes/mage.tscn",
		"res://scenes/red_wizard_woman.tscn"
	]
	
	for path in hero_paths:
		if ResourceLoader.exists(path):
			print("Found hero scene: " + path)
		else:
			print("Missing hero scene: " + path)
	
	# Check for hero icons
	var icon_paths = [
		"res://assets/heroes/mage_icon.png",
		"res://assets/mage_icon.png",
		"res://heroes/mage_icon.png",
		"res://mage_icon.png"
	]
	
	for path in icon_paths:
		if ResourceLoader.exists(path):
			print("Found hero icon: " + path)
		else:
			print("Missing hero icon: " + path)
	
	print("--- END RESOURCES ---\n")
