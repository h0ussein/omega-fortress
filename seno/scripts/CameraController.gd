# CameraController.gd
extends Camera2D

# Zoom settings
@export var min_zoom: float = 0.3  # Maximum zoom out (smaller value = more zoomed out)
@export var max_zoom: float = 2.0  # Maximum zoom in (larger value = more zoomed in)
@export var zoom_speed: float = 0.1  # How fast to zoom
@export var zoom_margin: float = 0.1  # Margin for zoom boundaries
@export var zoom_smoothing: float = 5.0  # Higher values = smoother zoom

# Pan settings
@export var pan_speed: float = 10.0
@export var edge_pan_margin: float = 50.0  # Pixels from edge to start panning
@export var keyboard_pan_speed: float = 500.0
@export var enable_edge_panning: bool = false  # Disable edge panning by default

# Internal variables
var target_zoom: Vector2 = Vector2(0.5, 0.5)  # Start with 0.5 zoom to see more of the grid
var is_panning: bool = false
var pan_start_position: Vector2 = Vector2.ZERO
var pan_relative_motion: Vector2 = Vector2.ZERO

func _ready():
	# Set initial zoom
	zoom = Vector2(0.5, 0.5)  # Start more zoomed out to see more of the grid
	target_zoom = zoom

	# Make sure we're at the origin (0,0) - this is where the base is
	position = Vector2.ZERO
	print("CameraController: Initial position set to (0,0)")

	print("CameraController: Ready with zoom range ", min_zoom, " to ", max_zoom)
	print("CameraController: Initial position at " + str(position))

func _process(delta):
	# Smoothly interpolate to target zoom
	zoom = zoom.lerp(target_zoom, zoom_smoothing * delta)

	# Handle keyboard panning
	var keyboard_pan = Vector2.ZERO

	if Input.is_action_pressed("ui_right"):
		keyboard_pan.x += 1
	if Input.is_action_pressed("ui_left"):
		keyboard_pan.x -= 1
	if Input.is_action_pressed("ui_down"):
		keyboard_pan.y += 1
	if Input.is_action_pressed("ui_up"):
		keyboard_pan.y -= 1

	if keyboard_pan != Vector2.ZERO:
		keyboard_pan = keyboard_pan.normalized() * keyboard_pan_speed * delta
		position += keyboard_pan

	# Handle edge panning (only if enabled)
	if enable_edge_panning:
		var mouse_pos = get_viewport().get_mouse_position()
		var viewport_size = get_viewport().size
		var edge_pan = Vector2.ZERO

		# Check if mouse is near edges
		if mouse_pos.x < edge_pan_margin:
			edge_pan.x = -1
		elif mouse_pos.x > viewport_size.x - edge_pan_margin:
			edge_pan.x = 1
			
		if mouse_pos.y < edge_pan_margin:
			edge_pan.y = -1
		elif mouse_pos.y > viewport_size.y - edge_pan_margin:
			edge_pan.y = 1

		if edge_pan != Vector2.ZERO:
			edge_pan = edge_pan.normalized() * pan_speed * delta
			position += edge_pan

	# Handle middle mouse panning
	if is_panning and pan_relative_motion != Vector2.ZERO:
		position -= pan_relative_motion * pan_speed * delta / zoom.x
		pan_relative_motion = Vector2.ZERO

func _input(event):
	# Check if we should ignore this input
	var main = get_node_or_null("/root/Node2D_main")
	var in_special_mode = false

	# Check if in move mode or barrier placement mode
	if main:
		if "move_mode" in main and main.move_mode:
			in_special_mode = true
		if main.has_node("BarrierPlacer") and is_instance_valid(main.get_node("BarrierPlacer")):
			var barrier_placer = main.get_node("BarrierPlacer")
			if "is_placing" in barrier_placer and barrier_placer.is_placing:
				in_special_mode = true

	# Handle mouse wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom in
			zoom_camera(-zoom_speed, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom out
			zoom_camera(zoom_speed, event.position)
		# Middle mouse button panning - only allow if not in special mode
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed and not in_special_mode:
				is_panning = true
				pan_start_position = event.position
			else:
				is_panning = false

	# Handle middle mouse panning
	if event is InputEventMouseMotion and is_panning:
		pan_relative_motion = event.position - pan_start_position
		pan_start_position = event.position

func zoom_camera(zoom_factor, mouse_position):
	# Calculate target zoom
	var new_zoom = target_zoom - Vector2(zoom_factor, zoom_factor)

	# Clamp zoom within limits
	new_zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
	new_zoom.y = clamp(new_zoom.y, min_zoom, max_zoom)

	# Set target zoom
	target_zoom = new_zoom

	print("CameraController: Zooming to ", target_zoom)

# Focus camera on a specific position
func focus_on(target_position: Vector2):
	position = target_position
	print("CameraController: Focused on position ", target_position)

# Enable or disable edge panning
func set_edge_panning(enabled: bool):
	enable_edge_panning = enabled
	print("CameraController: Edge panning " + ("enabled" if enabled else "disabled"))

# Reset camera to center on the base (0,0)
func reset_to_base():
	position = Vector2.ZERO
	print("CameraController: Reset to base position (0,0)")
