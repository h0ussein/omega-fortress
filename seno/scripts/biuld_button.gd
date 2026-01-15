extends CanvasLayer

# Signals
signal build_mode_toggled(is_active)

# References
@onready var build_button = $BuildButton

# Called when the node enters the scene tree for the first time.
func _ready():
	# Make sure the button is properly connected
	if not build_button.pressed.is_connected(_on_build_button_pressed):
		build_button.pressed.connect(_on_build_button_pressed)
		print("UILayer: Connected BuildButton signal")

# Handle build button press
func _on_build_button_pressed():
	print("UILayer: Build button pressed")
	
	# Toggle the button text
	if build_button.text == "Build Mode":
		build_button.text = "Exit Build Mode"
		print("UILayer: Emitting build_mode_toggled(true)")
		emit_signal("build_mode_toggled", true)
	else:
		build_button.text = "Build Mode"
		print("UILayer: Emitting build_mode_toggled(false)")
		emit_signal("build_mode_toggled", false)

# Public function to reset button state (can be called from main scene)
func reset_build_button():
	build_button.text = "Build Mode"
