# ZoomIndicator.gd
extends Label

var camera: Camera2D

func _ready():
	# Find the camera - try multiple paths
	camera = get_node_or_null("/root/Node2D_main/GameCamera")
	if not camera:
		camera = get_node_or_null("/root/Node2D_main/Camera2D")
	
	if not camera:
		print("ZoomIndicator: ERROR - Could not find camera")
		visible = false
	else:
		print("ZoomIndicator: Found camera at " + str(camera.get_path()))
	
	# Set initial position
	position = Vector2(20, 150)
	
	# Set initial text
	text = "Zoom: 100%"

func _process(delta):
	if camera and is_instance_valid(camera):
		# Update zoom text
		var zoom_percent = int(camera.zoom.x * 100)
		text = " Zoom: " + str(zoom_percent) + "%"
		
		# Make sure we're always visible on screen
		global_position = Vector2(20, 150)
