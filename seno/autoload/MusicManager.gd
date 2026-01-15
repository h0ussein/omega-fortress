extends Node
# MusicManager.gd - Global audio manager for handling music and sound effects

# Audio file paths
const GAME_MUSIC_PATH = "res://audio/game music.mp3"  # For menus and map
const MATCH_MUSIC_PATH = "res://audio/back_music.mp3"  # For actual gameplay
const SETTINGS_FILE_PATH = "user://audio_settings.cfg"

# Audio streams
var game_music: AudioStream
var match_music: AudioStream
var current_music_type: String = "none"  # "game" or "match"

# Audio players
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

# Volume settings (0.0 to 1.0)
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0

# Scene paths
var match_scene_path = "res://scenes/main.tscn"

# Disable automatic scene detection
var auto_scene_detection: bool = false

func _ready():
	print("DEBUG: MusicManager _ready() called")
	
	# Load music files
	print("DEBUG: Loading music files")
	game_music = load_audio_file(GAME_MUSIC_PATH)
	match_music = load_audio_file(MATCH_MUSIC_PATH)
	
	# Create music player
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.bus = "Music"
	
	# Create SFX player
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	sfx_player.bus = "SFX"
	
	# Ensure audio buses exist
	ensure_audio_buses_exist()
	
	# Load saved audio settings
	load_audio_settings()
	
	# Set initial music volume
	music_player.volume_db = linear_to_db(music_volume)
	
	# Start with game music by default
	play_game_music()

func load_audio_file(path: String) -> AudioStream:
	if FileAccess.file_exists(path):
		return load(path)
	else:
		print("DEBUG: Audio file not found: ", path)
		return null

func ensure_audio_buses_exist():
	var audio_bus_count = AudioServer.get_bus_count()
	var music_bus_idx = AudioServer.get_bus_index("Music")
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	
	# Create Music bus if it doesn't exist
	if music_bus_idx == -1:
		print("DEBUG: Creating Music bus")
		AudioServer.add_bus()
		music_bus_idx = audio_bus_count
		AudioServer.set_bus_name(music_bus_idx, "Music")
		AudioServer.set_bus_send(music_bus_idx, "Master")
	
	# Create SFX bus if it doesn't exist
	if sfx_bus_idx == -1:
		print("DEBUG: Creating SFX bus")
		AudioServer.add_bus()
		sfx_bus_idx = audio_bus_count + (1 if music_bus_idx == -1 else 0)
		AudioServer.set_bus_name(sfx_bus_idx, "SFX")
		AudioServer.set_bus_send(sfx_bus_idx, "Master")

func load_audio_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE_PATH)
	
	if err == OK:
		# Load settings
		master_volume = config.get_value("audio", "master_volume", 1.0)
		music_volume = config.get_value("audio", "music_volume", 1.0)
		sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
		
		# Apply settings
		set_master_volume(master_volume)
		set_music_volume(music_volume)
		set_sfx_volume(sfx_volume)
	else:
		# Use defaults
		set_master_volume(1.0)
		set_music_volume(1.0)
		set_sfx_volume(1.0)

func save_audio_settings():
	var config = ConfigFile.new()
	
	# Save settings
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	
	# Write to file
	config.save(SETTINGS_FILE_PATH)

func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	
	# Apply to buses
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))
	
	# Save settings
	save_audio_settings()

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
	
	# Apply to music bus
	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx >= 0:
		AudioServer.set_bus_volume_db(music_bus_idx, linear_to_db(music_volume))
	
	# Apply to current music player
	if music_player:
		music_player.volume_db = linear_to_db(music_volume)
	
	# Save settings
	save_audio_settings()

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0.0, 1.0)
	
	# Apply to SFX bus
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if sfx_bus_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_bus_idx, linear_to_db(sfx_volume))
	
	# Save settings
	save_audio_settings()

func play_game_music():
	print("DEBUG: play_game_music called")
	if game_music and current_music_type != "game":
		current_music_type = "game"
		_play_music(game_music)

func play_match_music():
	print("DEBUG: play_match_music called")
	if match_music and current_music_type != "match":
		current_music_type = "match"
		_play_music(match_music)

func _play_music(music_stream: AudioStream):
	if music_stream == null:
		return
	
	# Stop current music
	music_player.stop()
	
	# Set new music
	music_player.stream = music_stream
	
	# Enable looping for MP3 files
	if music_stream is AudioStreamMP3:
		music_stream.loop = true
	
	# Set volume
	music_player.volume_db = linear_to_db(music_volume)
	
	# Play music
	music_player.play()
