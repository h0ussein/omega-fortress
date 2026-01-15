extends Control

@onready var Settings = $Settings
@onready var videos = $video
@onready var audio = $audio
@onready var container = $VBoxContainer
@onready var back = $"back from settings"
@onready var backFromVideo = $"video/back from video"
@onready var backfromAudio = $"audio/back from audio"

# Audio sliders with correct paths based on your scene tree
@onready var master_slider = $audio/HBoxContainer/slider/master
@onready var music_slider = $audio/HBoxContainer/slider/music
@onready var sound_fx_slider = $audio/HBoxContainer/slider/"sound fx"

# Direct reference to MusicManager
var music_manager

func toggle():
	visible = !visible
	get_tree().paused = visible
	print("DEBUG: Settings visibility toggled to: ", visible)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("DEBUG: Settings _ready() called")
	
	# Get direct reference to MusicManager
	music_manager = get_node_or_null("/root/MusicManager")
	print("DEBUG: MusicManager found directly: ", is_instance_valid(music_manager))
	
	# Using your exact visibility setup
	container.show()
	back.show()
	videos.hide()
	audio.hide()
	backfromAudio.hide()
	backFromVideo.hide()
	
	print("DEBUG: Visibility set")
	
	# Debug node existence
	print("DEBUG: master_slider exists: ", is_instance_valid(master_slider))
	print("DEBUG: music_slider exists: ", is_instance_valid(music_slider))
	print("DEBUG: sound_fx_slider exists: ", is_instance_valid(sound_fx_slider))
	
	# Connect slider signals in code
	if master_slider:
		if not master_slider.is_connected("value_changed", _on_master_value_changed):
			master_slider.value_changed.connect(_on_master_value_changed)
			print("DEBUG: Connected master_slider signal")
		else:
			print("DEBUG: master_slider signal already connected")
	else:
		print("DEBUG: master_slider not found!")
	
	if music_slider:
		if not music_slider.is_connected("value_changed", _on_music_value_changed):
			music_slider.value_changed.connect(_on_music_value_changed)
			print("DEBUG: Connected music_slider signal")
		else:
			print("DEBUG: music_slider signal already connected")
	else:
		print("DEBUG: music_slider not found!")
	
	if sound_fx_slider:
		if not sound_fx_slider.is_connected("value_changed", _on_sound_fx_value_changed):
			sound_fx_slider.value_changed.connect(_on_sound_fx_value_changed)
			print("DEBUG: Connected sound_fx_slider signal")
		else:
			print("DEBUG: sound_fx_slider signal already connected")
	else:
		print("DEBUG: sound_fx_slider not found!")
	
	# Initialize sliders with current values from MusicManager (if it exists)
	if music_manager:
		print("DEBUG: Initializing sliders from MusicManager")
		
		if music_slider:
			music_slider.value = music_manager.music_volume * 100  # Convert 0-1 to 0-100
			print("DEBUG: Set music_slider value to: ", music_slider.value)
		
		if sound_fx_slider:
			sound_fx_slider.value = music_manager.sfx_volume * 100  # Convert 0-1 to 0-100
			print("DEBUG: Set sound_fx_slider value to: ", sound_fx_slider.value)
			
		if master_slider:
			master_slider.value = music_manager.master_volume * 100
			print("DEBUG: Set master_slider value to: ", master_slider.value)
	else:
		print("DEBUG: MusicManager not found for slider initialization!")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func show_and_hide(a,b):
	a.show()
	b.hide()
	print("DEBUG: show_and_hide called - showing: ", a.name, ", hiding: ", b.name)

func _on_video_pressed():
	print("DEBUG: Video button pressed")
	videos.show()
	container.hide()
	backFromVideo.show()
	back.hide()

func _on_audio_pressed() -> void:
	print("DEBUG: Audio button pressed")
	audio.show()
	backfromAudio.show()
	container.hide()
	back.hide()
	
	# Refresh slider values when opening audio settings
	if music_manager:
		print("DEBUG: Refreshing slider values from MusicManager")
		
		if music_slider:
			music_slider.value = music_manager.music_volume * 100
			print("DEBUG: Refreshed music_slider value to: ", music_slider.value)
		
		if sound_fx_slider:
			sound_fx_slider.value = music_manager.sfx_volume * 100
			print("DEBUG: Refreshed sound_fx_slider value to: ", sound_fx_slider.value)
			
		if master_slider:
			master_slider.value = music_manager.master_volume * 100
			print("DEBUG: Refreshed master_slider value to: ", master_slider.value)

func _on_back_from_video_pressed() -> void:
	print("DEBUG: Back from video pressed")
	_ready()  # This calls your original _ready() function which sets up visibility

func _on_back_from_audio_pressed() -> void:
	print("DEBUG: Back from audio pressed")
	_ready()  # This calls your original _ready() function which sets up visibility

func _on_back_from_settings_pressed() -> void:
	print("DEBUG: Back from settings pressed")
	get_tree().change_scene_to_file("res://interface/main_menu.tscn")

func _on_vsync_toggled(toggled_on: bool) -> void:
	print("DEBUG: VSync toggled: ", toggled_on)
	pass # Replace with function body.

func _on_borderless_toggled(toggled_on: bool) -> void:
	print("DEBUG: Borderless toggled: ", toggled_on)
	pass # Replace with function body.

func _on_master_value_changed(value: float) -> void:
	print("DEBUG: Master slider value changed to: ", value)
	
	# Master affects both music and sound fx
	if music_manager:
		# Convert slider value (0-100) to volume (0-1)
		var volume = value / 100.0
		print("DEBUG: Setting master volume to: ", volume)
		
		# Set master volume
		music_manager.set_master_volume(volume)
		
		# Update the other sliders to match
		if music_slider:
			music_slider.value = value
			print("DEBUG: Updated music_slider to match: ", value)
		
		if sound_fx_slider:
			sound_fx_slider.value = value
			print("DEBUG: Updated sound_fx_slider to match: ", value)
	else:
		print("DEBUG: MusicManager not found when changing master volume!")

func _on_music_value_changed(value: float) -> void:
	print("DEBUG: Music slider value changed to: ", value)
	
	if music_manager:
		# Convert slider value (0-100) to volume (0-1)
		var volume = value / 100.0
		print("DEBUG: Setting music volume to: ", volume)
		
		# Update the music volume in the MusicManager
		music_manager.set_music_volume(volume)
		
		# Optional: Play a short sample if not already playing
		if not music_manager.music_player.playing:
			print("DEBUG: Music not playing, starting playback")
			if music_manager.has_method("play_game_music"):
				music_manager.play_game_music()
	else:
		print("DEBUG: MusicManager not found when changing music volume!")

func _on_sound_fx_value_changed(value: float) -> void:
	print("DEBUG: Sound FX slider value changed to: ", value)
	
	if music_manager:
		# Convert slider value (0-100) to volume (0-1)
		var volume = value / 100.0
		print("DEBUG: Setting SFX volume to: ", volume)
		
		# Update the SFX volume in the MusicManager
		music_manager.set_sfx_volume(volume)
		
		# Optional: Play a test sound effect
		print("DEBUG: Playing test sound")
		play_test_sound()
	else:
		print("DEBUG: MusicManager not found when changing SFX volume!")

# Optional: Function to play a test sound when adjusting SFX volume
func play_test_sound() -> void:
	print("DEBUG: play_test_sound called")
	
	# Create a temporary AudioStreamPlayer for the test sound
	var test_player = AudioStreamPlayer.new()
	add_child(test_player)
	
	# Try to load the test sound
	var sound_path = "res://assets/audio/test_sound.ogg"  # Update path
	print("DEBUG: Loading test sound from: ", sound_path)
	
	if ResourceLoader.exists(sound_path):
		var sound = load(sound_path)
		if sound:
			print("DEBUG: Test sound loaded successfully")
			test_player.stream = sound
			test_player.bus = "SFX"
			
			# Play the sound and remove the player when done
			test_player.play()
			print("DEBUG: Test sound playing")
			await test_player.finished
			test_player.queue_free()
			print("DEBUG: Test sound finished, player removed")
		else:
			print("DEBUG: Failed to load test sound from: ", sound_path)
			generate_test_tone(test_player)
	else:
		print("DEBUG: Test sound file does not exist: ", sound_path)
		generate_test_tone(test_player)

# Generate a test tone if no sound file is available
func generate_test_tone(player: AudioStreamPlayer) -> void:
	print("DEBUG: Generating test tone")
	
	# Create a simple tone generator
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050.0  # Hz
	generator.buffer_length = 0.1  # seconds
	
	player.stream = generator
	player.volume_db = 0  # Full volume for test
	player.bus = "SFX"
	player.play()
	
	# Get the playback object
	var playback = player.get_stream_playback()
	
	# Fill the buffer with a simple wave
	var phase = 0.0
	var increment = 880.0 / 22050.0  # 880 Hz tone (higher pitch than music test)
	
	# Only push frames if we have a valid playback
	if playback:
		var frames_available = playback.get_frames_available()
		print("DEBUG: Generating ", frames_available, " frames of audio")
		
		for i in range(frames_available):
			var sample = sin(phase * TAU) * 0.5  # Simple sine wave at half volume
			playback.push_frame(Vector2(sample, sample))  # Stereo
			phase += increment
			phase = fmod(phase, 1.0)
		
		print("DEBUG: Test tone playing for 0.5 seconds")
	else:
		print("DEBUG: Failed to get stream playback for test tone")
	
	# Clean up after a short delay
	await get_tree().create_timer(0.5).timeout
	player.queue_free()
	print("DEBUG: Test tone finished")

# Add a test button to directly test audio
func _on_test_audio_button_pressed() -> void:
	print("DEBUG: Test audio button pressed")
	
	if music_manager:
		music_manager.test_audio_output()
	else:
		# Create a direct audio test if MusicManager is not available
		var test_player = AudioStreamPlayer.new()
		add_child(test_player)
		generate_test_tone(test_player)
