# HeroPanel.gd
extends Control

signal move_button_pressed
signal sell_button_pressed

var panel
var move_button
var sell_button
var button_interaction_timer: Timer

func _ready():
	print("HeroPanel: Ready")

	# Create required nodes if they don't exist
	create_required_nodes()

	# Create a timer to delay button interactions
	button_interaction_timer = Timer.new()
	button_interaction_timer.one_shot = true
	button_interaction_timer.wait_time = 0.2  # 200ms delay
	button_interaction_timer.timeout.connect(_on_button_interaction_timer_timeout)
	add_child(button_interaction_timer)

	# Connect button signals
	connect_button_signals()

	# Hide panel initially
	visible = false

	# Make sure the panel is not affected by camera zoom
	set_as_top_level(true)

func create_required_nodes():
	# Make sure the Control node has the right size
	custom_minimum_size = Vector2(120, 100)
	size = Vector2(120, 100)

	# Create Panel if it doesn't exist
	panel = get_node_or_null("Panel")
	if not panel:
		print("HeroPanel: Creating Panel node")
		panel = Panel.new()
		panel.name = "Panel"
		panel.anchor_right = 1.0
		panel.anchor_bottom = 1.0
		panel.offset_left = 0
		panel.offset_top = 0
		panel.offset_right = 0
		panel.offset_bottom = 0
		add_child(panel)
	
	# Create VBoxContainer if it doesn't exist
	var vbox_container = panel.get_node_or_null("VBoxContainer")
	if not vbox_container:
		print("HeroPanel: Creating VBoxContainer node")
		vbox_container = VBoxContainer.new()
		vbox_container.name = "VBoxContainer"
		vbox_container.anchor_right = 1.0
		vbox_container.anchor_bottom = 1.0
		vbox_container.offset_left = 5
		vbox_container.offset_top = 5
		vbox_container.offset_right = -5
		vbox_container.offset_bottom = -5
		vbox_container.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(vbox_container)
	
	# Create MoveButton if it doesn't exist
	move_button = vbox_container.get_node_or_null("MoveButton")
	if not move_button:
		print("HeroPanel: Creating MoveButton node")
		move_button = Button.new()
		move_button.name = "MoveButton"
		move_button.text = "Move"
		move_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		move_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox_container.add_child(move_button)
	
	# Create SellButton if it doesn't exist
	sell_button = vbox_container.get_node_or_null("SellButton")
	if not sell_button:
		print("HeroPanel: Creating SellButton node")
		sell_button = Button.new()
		sell_button.name = "SellButton"
		sell_button.text = "Sell"
		sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sell_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox_container.add_child(sell_button)

func connect_button_signals():
	# Disconnect existing signals to avoid duplicates
	if move_button:
		if move_button.pressed.is_connected(_on_move_button_pressed):
			move_button.pressed.disconnect(_on_move_button_pressed)
		# Connect with explicit reference to this instance
		move_button.pressed.connect(_on_move_button_pressed.bind())
		print("HeroPanel: Connected MoveButton signal")
	else:
		print("HeroPanel: ERROR - MoveButton not found")

	if sell_button:
		if sell_button.pressed.is_connected(_on_sell_button_pressed):
			sell_button.pressed.disconnect(_on_sell_button_pressed)
		# Connect with explicit reference to this instance
		sell_button.pressed.connect(_on_sell_button_pressed.bind())
		print("HeroPanel: Connected SellButton signal")
	else:
		print("HeroPanel: ERROR - SellButton not found")

func show_panel():
	# Disable buttons initially to prevent accidental clicks
	if move_button:
		move_button.disabled = true
	if sell_button:
		sell_button.disabled = true
	
	# Start the timer to enable buttons after a delay
	button_interaction_timer.start()
	
	# Show the panel
	visible = true
	
	# Make sure signals are connected
	connect_button_signals()

func _on_button_interaction_timer_timeout():
	# Enable buttons after the delay
	if move_button:
		move_button.disabled = false
		print("HeroPanel: Move button enabled")
	if sell_button:
		sell_button.disabled = false
		print("HeroPanel: Sell button enabled")
	
	print("HeroPanel: Buttons enabled")

func _on_move_button_pressed():
	print("HeroPanel: Move button pressed")
	emit_signal("move_button_pressed")

func _on_sell_button_pressed():
	print("HeroPanel: Sell button pressed")
	emit_signal("sell_button_pressed")

# Override _input to handle button clicks directly
func _input(event):
	if not visible or not move_button or not sell_button:
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if click is on move button
		var move_rect = Rect2(move_button.global_position, move_button.size)
		if move_rect.has_point(event.global_position) and not move_button.disabled:
			print("HeroPanel: Move button clicked directly")
			_on_move_button_pressed()
			get_viewport().set_input_as_handled()
			
		# Check if click is on sell button
		var sell_rect = Rect2(sell_button.global_position, sell_button.size)
		if sell_rect.has_point(event.global_position) and not sell_button.disabled:
			print("HeroPanel: Sell button clicked directly")
			_on_sell_button_pressed()
			get_viewport().set_input_as_handled()
