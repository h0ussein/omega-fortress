extends Node2D

# This script helps visualize pathfinding for debugging
# Attach it to a Node2D in your scene

@export var enabled: bool = true
@export var path_color: Color = Color(1, 0, 0, 0.5)
@export var point_color: Color = Color(0, 1, 0, 0.8)
@export var point_size: float = 5.0

var current_path = []
var grid_system = null

func _ready():
	# Find the grid system
	grid_system = get_node_or_null("/root/Node2D_main/GridSystem")
	
	if not grid_system:
		print("DebugPathfinding: Could not find GridSystem")
		enabled = false

func _process(delta):
	if not enabled or not grid_system:
		return
	
	# Find all enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	# Update paths for visualization
	for enemy in enemies:
		if enemy.has_method("get_current_path"):
			var path = enemy.get_current_path()
			if path.size() > 0:
				current_path = path
				queue_redraw()
				break

func _draw():
	if not enabled or current_path.size() < 2:
		return
	
	# Draw lines between path points
	for i in range(current_path.size() - 1):
		draw_line(current_path[i], current_path[i+1], path_color, 2.0)
	
	# Draw points
	for point in current_path:
		draw_circle(point, point_size, point_color)

# Call this to force a redraw
func update_visualization():
	queue_redraw()
