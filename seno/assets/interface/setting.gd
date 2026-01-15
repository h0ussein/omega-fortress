extends Control

@onready var Settings = $Settings
@onready var videos = $video
@onready var audio = $audio
@onready var container = $VBoxContainer
@onready var back = $"back from settings"
@onready var backFromVideo = $"video/back from video"
@onready var backfromAudio = $"audio/back from audio"


func toggle():
	visible = !visible
	get_tree().paused = visible

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	container.show()
	back.show()
	videos.hide()
	audio.hide()
	backfromAudio.hide()
	backFromVideo.hide()
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func show_and_hide(a,b):
	a.show()
	b.hide()

func _on_video_pressed():
	videos.show()
	container.hide()
	backFromVideo.show()
	back.hide()
	


func _on_audio_pressed() -> void:
	audio.show()
	backfromAudio.show()
	container.hide()
	back.hide()


func _on_back_from_video_pressed() -> void:
	_ready()


func _on_back_from_audio_pressed() -> void:
	_ready()


func _on_back_from_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")


func _on_vsync_toggled(toggled_on: bool) -> void:
	pass # Replace with function body.


func _on_borderless_toggled(toggled_on: bool) -> void:
	pass # Replace with function body.





func _on_music_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_sound_fx_value_changed(value: float) -> void:
	pass # Replace with function body.
