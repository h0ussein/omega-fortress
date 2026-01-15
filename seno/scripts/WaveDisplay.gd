extends Control

# Signal connections
signal wave_display_updated

# References
var wave_manager = null
var main_scene = null
var is_paused = false

# Wave information
var current_wave = 1
var total_waves = 15
var enemies_remaining = 0
var total_enemies_in_wave = 0
var time_to_next_wave = 0
var wave_in_progress = false
var countdown_active = false
var is_boss_wave = false  # Added for boss wave tracking

# UI elements
var wave_info_panel = null
var wave_label = null
var enemy_label = null
var progress_bar = null
var countdown_label = null
var next_wave_button = null
var wave_announcement_label = null  # New label for wave announcements
var wave_announcement_timer = null  # Timer to hide the announcement
var boss_indicator = null  # New UI element for boss waves

func _ready():
	print("WaveDisplayManager: _ready() called")
	add_to_group("wave_display_manager")
	
	# Set up UI elements programmatically
	create_ui_elements()
	
	# Find wave manager
	wave_manager = get_node_or_null("/root/Node2D_main/WaveManager")
	if not wave_manager:
		var potential_managers = get_tree().get_nodes_in_group("wave_manager")
		if potential_managers.size() > 0:
			wave_manager = potential_managers[0]
			print("WaveDisplayManager: Found WaveManager in group")
		else:
			print("WaveDisplayManager: WARNING - WaveManager not found")
	else:
		print("WaveDisplayManager: Found WaveManager at path")
	
	# Find main scene
	main_scene = get_node_or_null("/root/Node2D_main")
	if main_scene:
		print("WaveDisplayManager: Found main scene")
	else:
		print("WaveDisplayManager: WARNING - Main scene not found")
	
	# Connect to wave manager signals
	if wave_manager:
		if wave_manager.has_signal("wave_started"):
			wave_manager.wave_started.connect(_on_wave_started)
			print("WaveDisplayManager: Connected wave_started signal")
		
		if wave_manager.has_signal("wave_completed"):
			wave_manager.wave_completed.connect(_on_wave_completed)
			print("WaveDisplayManager: Connected wave_completed signal")
		
		if wave_manager.has_signal("countdown_tick"):
			wave_manager.countdown_tick.connect(_on_countdown_tick)
			print("WaveDisplayManager: Connected countdown_tick signal")
		
		if wave_manager.has_signal("enemy_killed"):
			wave_manager.enemy_killed.connect(_on_enemy_killed)
			print("WaveDisplayManager: Connected enemy_killed signal")
		
		if wave_manager.has_signal("boss_wave_started"):
			wave_manager.boss_wave_started.connect(_on_boss_wave_started)
			print("WaveDisplayManager: Connected boss_wave_started signal")
		
		# Get initial values
		if wave_manager.has_method("get_current_wave"):
			current_wave = wave_manager.get_current_wave()
		
		if wave_manager.has_method("get_total_waves"):
			total_waves = wave_manager.get_total_waves()
		
		if wave_manager.has_method("get_time_to_next_wave"):
			time_to_next_wave = wave_manager.get_time_to_next_wave()
		
		if wave_manager.has_method("is_wave_in_progress"):
			wave_in_progress = wave_manager.is_wave_in_progress()
		
		if wave_manager.has_method("is_countdown_active"):
			countdown_active = wave_manager.is_countdown_active()
		
		if wave_manager.has_method("get_enemies_remaining"):
			enemies_remaining = wave_manager.get_enemies_remaining()
		
		if wave_manager.has_method("is_boss_wave"):
			is_boss_wave = wave_manager.is_boss_wave()
	
	# Initial update
	update_display()
	
	print("WaveDisplayManager: Ready")

func create_ui_elements():
	print("WaveDisplayManager: Creating UI elements")
	
	# Create main panel
	wave_info_panel = Panel.new()
	wave_info_panel.name = "WaveInfoPanel"
	
	# Set up anchoring to center top
	wave_info_panel.anchor_left = 0.5
	wave_info_panel.anchor_right = 0.5
	wave_info_panel.anchor_top = 0.0
	wave_info_panel.anchor_bottom = 0.0
	
	# Set position relative to anchor (center top)
	wave_info_panel.offset_left = -120
	wave_info_panel.offset_top = 10
	wave_info_panel.offset_right = 150
	wave_info_panel.offset_bottom = 110
	
	# Add a visible style to the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray, semi-transparent
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	wave_info_panel.add_theme_stylebox_override("panel", style)
	
	add_child(wave_info_panel)
	
	# Create wave label
	wave_label = Label.new()
	wave_label.name = "WaveLabel"
	wave_label.anchor_left = 0.5
	wave_label.anchor_right = 0.5
	wave_label.offset_left = -100
	wave_label.offset_top = 5
	wave_label.offset_right = 100
	wave_label.offset_bottom = 31
	wave_label.text = "Wave: 1 / 15"
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_info_panel.add_child(wave_label)
	
	# Create enemy label
	enemy_label = Label.new()
	enemy_label.name = "EnemyLabel"
	enemy_label.anchor_left = 0.5
	enemy_label.anchor_top = 0.5
	enemy_label.anchor_right = 0.5
	enemy_label.anchor_bottom = 0.5
	enemy_label.offset_left = -100
	enemy_label.offset_top = -13
	enemy_label.offset_right = 100
	enemy_label.offset_bottom = 13
	enemy_label.text = "Enemies: 0"
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_info_panel.add_child(enemy_label)
	
	# Create progress bar

	
	# Create countdown label
	countdown_label = Label.new()
	countdown_label.name = "CountdownLabel"
	countdown_label.anchor_left = 0.5
	countdown_label.anchor_top = 1.0
	countdown_label.anchor_right = 0.5
	countdown_label.anchor_bottom = 1.0
	countdown_label.offset_left = -100
	countdown_label.offset_top = -20
	countdown_label.offset_right = 100
	countdown_label.offset_bottom = 6
	countdown_label.text = "Next wave in: 10s"
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_info_panel.add_child(countdown_label)
	
	# Create next wave button
	next_wave_button = Button.new()
	next_wave_button.name = "NextWaveButton"
	next_wave_button.anchor_left = 0.5
	next_wave_button.anchor_top = 1.0
	next_wave_button.anchor_right = 0.5
	next_wave_button.anchor_bottom = 1.0
	next_wave_button.offset_left = -60
	next_wave_button.offset_top = 10
	next_wave_button.offset_right = 60
	next_wave_button.offset_bottom = 41
	next_wave_button.text = "Start Wave"
	next_wave_button.pressed.connect(_on_next_wave_button_pressed)
	wave_info_panel.add_child(next_wave_button)
	
	# Create boss indicator
	boss_indicator = Label.new()
	boss_indicator.name = "BossIndicator"
	boss_indicator.anchor_left = 0.5
	boss_indicator.anchor_right = 0.5
	boss_indicator.offset_left = -100
	boss_indicator.offset_top = -20
	boss_indicator.offset_right = 100
	boss_indicator.offset_bottom = 0
	boss_indicator.text = "BOSS WAVE"
	boss_indicator.add_theme_font_size_override("font_size", 16)
	boss_indicator.add_theme_color_override("font_color", Color(1, 0, 0))  # Red color
	boss_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_indicator.visible = false  # Hidden by default
	wave_info_panel.add_child(boss_indicator)
	
	# Create wave announcement label (positioned at extreme right edge, initially hidden)
	wave_announcement_label = Label.new()
	wave_announcement_label.name = "WaveAnnouncementLabel"
	wave_announcement_label.anchor_left = 0.98  # Extreme right (98% from left)
	wave_announcement_label.anchor_right = 0.98  # Extreme right
	wave_announcement_label.anchor_top = 0.4  
	wave_announcement_label.anchor_bottom = 0.4
	wave_announcement_label.offset_left = 250  # Offset to the left of anchor point
	wave_announcement_label.offset_top = -30
	wave_announcement_label.offset_right = 0    # Right edge aligned with anchor
	wave_announcement_label.offset_bottom = 30
	wave_announcement_label.text = "WAVE 1"
	wave_announcement_label.add_theme_font_size_override("font_size", 42)
	wave_announcement_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2)) # Gold color
	wave_announcement_label.add_theme_constant_override("shadow_offset_x", 2)
	wave_announcement_label.add_theme_constant_override("shadow_offset_y", 2)
	wave_announcement_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	wave_announcement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT  # Right-aligned text
	wave_announcement_label.visible = false
	add_child(wave_announcement_label)  # Make sure to add it to the scene
	
	# Create timer for wave announcement
	wave_announcement_timer = Timer.new()
	wave_announcement_timer.one_shot = true
	wave_announcement_timer.wait_time = 3.0  # Show for 3 seconds
	wave_announcement_timer.timeout.connect(_on_wave_announcement_timeout)
	add_child(wave_announcement_timer)
	
	print("WaveDisplayManager: UI elements created")

func _process(delta):
	if is_paused:
		return
	
	# Keep the display updated
	update_display()

func update_display():
	# Update wave label
	if wave_label:
		wave_label.text = "Wave: " + str(current_wave) + " / " + str(total_waves)
	
	# Update enemy label
	if enemy_label:
		enemy_label.text = "Enemies: " + str(enemies_remaining)
	
	# Update progress bar
	if progress_bar and total_enemies_in_wave > 0:
		var progress = float(total_enemies_in_wave - enemies_remaining) / float(total_enemies_in_wave)
		progress_bar.value = progress * 100
	
	# Update countdown label and button visibility
	if countdown_label:
		if countdown_active and time_to_next_wave > 0:
			countdown_label.text = "Next wave in: " + str(int(time_to_next_wave)) + "s"
			countdown_label.visible = true
		elif wave_in_progress:
			countdown_label.text = "Wave in progress"
			countdown_label.visible = true
		else:
			countdown_label.visible = false
	
	if next_wave_button:
		next_wave_button.visible = countdown_active and time_to_next_wave > 0
	
	# Update boss indicator
	if boss_indicator:
		boss_indicator.visible = is_boss_wave
		
		# Make it blink if visible
		if is_boss_wave:
			var time = Time.get_ticks_msec() / 500.0  # Half-second intervals
			boss_indicator.visible = int(time) % 2 == 0  # Blink on and off
	
	emit_signal("wave_display_updated")

func _on_wave_started(wave_number):
	current_wave = wave_number
	wave_in_progress = true
	countdown_active = false
	
	# Get total enemies in this wave
	if wave_manager and wave_manager.has_method("get_enemies_remaining"):
		enemies_remaining = wave_manager.get_enemies_remaining()
		total_enemies_in_wave = enemies_remaining
	
	print("WaveDisplayManager: Wave " + str(wave_number) + " started with " + str(enemies_remaining) + " enemies")
	update_display()
	check_boss_wave()

	# Show wave announcement
	if wave_announcement_label:
		if is_boss_wave:
			wave_announcement_label.text = "BOSS WAVE " + str(wave_number)
			wave_announcement_label.add_theme_color_override("font_color", Color(1, 0, 0)) # Red for boss waves
		else:
			wave_announcement_label.text = "WAVE " + str(wave_number)
			wave_announcement_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2)) # Gold for normal waves
		
		wave_announcement_label.visible = true
		wave_announcement_timer.start()
		print("WaveDisplayManager: Wave announcement shown for wave " + str(wave_number))
	
	# Check if this is a boss wave

func _on_wave_completed(wave_number):
	wave_in_progress = false
	print("WaveDisplayManager: Wave " + str(wave_number) + " completed")
	update_display()

func _on_countdown_tick(time_left):
	time_to_next_wave = time_left
	countdown_active = true
	update_display()

func _on_enemy_killed(enemy):
	if enemies_remaining > 0:
		enemies_remaining -= 1
	update_display()

func _on_boss_wave_started(wave_number):
	is_boss_wave = true
	print("WaveDisplayManager: Boss wave " + str(wave_number) + " started!")
	update_display()
	
	# Update panel style for boss wave
	if wave_info_panel:
		var style = wave_info_panel.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			style.bg_color = Color(0.5, 0.1, 0.1, 0.8)  # Red tint for boss waves

func _on_next_wave_button_pressed():
	if wave_manager and wave_manager.has_method("skip_countdown"):
		wave_manager.skip_countdown()
		print("WaveDisplayManager: Next wave button pressed")

func set_paused(paused):
	is_paused = paused
	print("WaveDisplayManager: Paused state set to " + str(is_paused))

# Check if current wave is a boss wave and update display accordingly
func check_boss_wave():
	if wave_manager and wave_manager.has_method("is_boss_wave"):
		is_boss_wave = wave_manager.is_boss_wave()
		
		if is_boss_wave and wave_info_panel:
			# Highlight panel for boss wave
			var style = wave_info_panel.get_theme_stylebox("panel")
			if style is StyleBoxFlat:
				style.bg_color = Color(0.5, 0.1, 0.1, 0.8)  # Red tint for boss waves
		else:
			# Reset to normal color
			var style = wave_info_panel.get_theme_stylebox("panel")
			if style is StyleBoxFlat:
				style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Normal color

# New function to handle hiding the wave announcement
func _on_wave_announcement_timeout():
	if wave_announcement_label:
		wave_announcement_label.visible = false
	print("WaveDisplayManager: Wave announcement hidden")
