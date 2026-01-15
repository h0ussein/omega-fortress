extends Control

@onready var wave_label = $WaveLabel
@onready var countdown_label = $CountdownLabel
@onready var next_wave_button = $NextWaveButton

var wave_manager = null

func _ready():
	print("WaveDisplay: _ready() called")

	# Try to find the wave manager, but don't error if not found yet
	wave_manager = get_node_or_null("/root/Node2D_main/WaveManager")
	print("WaveDisplay: Initial WaveManager reference: ", wave_manager)
	
	# Connect signals if wave_manager exists
	if wave_manager:
		connect_signals()
	
	# Connect button signal
	print("WaveDisplay: Connecting NextWaveButton pressed signal")
	if next_wave_button:
		next_wave_button.pressed.connect(_on_next_wave_button_pressed)
		print("WaveDisplay: NextWaveButton connected")
	else:
		print("WaveDisplay: ERROR - NextWaveButton not found")

	# Initial update
	update_display()

	print("WaveDisplay: Ready complete")

func connect_signals():
	if not wave_manager:
		return
		
	print("WaveDisplay: Connecting signals to WaveManager")
	
	if wave_manager.has_signal("wave_started"):
		if not wave_manager.wave_started.is_connected(_on_wave_started):
			wave_manager.wave_started.connect(_on_wave_started)
			print("WaveDisplay: Connected wave_started signal")
	else:
		print("WaveDisplay: ERROR - wave_started signal does not exist")

	if wave_manager.has_signal("wave_completed"):
		if not wave_manager.wave_completed.is_connected(_on_wave_completed):
			wave_manager.wave_completed.connect(_on_wave_completed)
			print("WaveDisplay: Connected wave_completed signal")
	else:
		print("WaveDisplay: ERROR - wave_completed signal does not exist")

	if wave_manager.has_signal("countdown_tick"):
		if not wave_manager.countdown_tick.is_connected(_on_countdown_tick):
			wave_manager.countdown_tick.connect(_on_countdown_tick)
			print("WaveDisplay: Connected countdown_tick signal")
	else:
		print("WaveDisplay: ERROR - countdown_tick signal does not exist")

func _process(delta):
	# If wave_manager is null, try to find it again
	if not wave_manager:
		wave_manager = get_node_or_null("/root/Node2D_main/WaveManager")
		if wave_manager:
			print("WaveDisplay: Found WaveManager in _process")
			connect_signals()
	
	# Keep the display updated
	update_display()

func update_display():
	if not wave_manager:
		# Don't spam the console with errors
		return

	# Update wave label
	var current_wave = wave_manager.get_current_wave()
	var total_waves = wave_manager.get_total_waves()
	
	wave_label.text = "Wave: " + str(current_wave) + " / " + str(total_waves)

	# Update countdown label and button visibility
	if wave_manager.is_countdown_active():
		var time_left = wave_manager.get_time_to_next_wave()
		countdown_label.text = "Next wave in: " + str(int(time_left)) + "s"
		countdown_label.visible = true
		next_wave_button.visible = true
	elif wave_manager.is_wave_in_progress():
		countdown_label.text = "Wave in progress"
		countdown_label.visible = true
		next_wave_button.visible = false
	else:
		countdown_label.visible = false
		next_wave_button.visible = false

func _on_wave_started(wave_number):
	update_display()

func _on_wave_completed(wave_number):
	update_display()

func _on_countdown_tick(time_left):
	# This is handled in update_display, but we could optimize by updating only when needed
	pass

func _on_next_wave_button_pressed():
	print("WaveDisplay: Next wave button pressed")
	if wave_manager and wave_manager.is_countdown_active():
		print("WaveDisplay: Skipping countdown")
		wave_manager.skip_countdown()
	else:
		print("WaveDisplay: Cannot skip countdown - wave_manager is null or countdown not active")
