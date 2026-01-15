extends Control

@export var loading_bar: ProgressBar
@onready var percentage_label: Label = $percentage_label # Add a Label node for displaying text
var scene_path: String 
var progress : Array  # Initialize as empty array

func _ready() -> void:
	print("ready function are excuted")
	scene_path = "res://map.tscn"
	print("a")
	ResourceLoader.load_threaded_request(scene_path)
	print("b")


func _process(delta):
	print("c")
	ResourceLoader.load_threaded_get_status(scene_path, progress)
	
	loading_bar.value = progress[0]
	percentage_label.text= str(progress[0]*100.0)
	
	if loading_bar.value>=1.0:
		get_tree().change_scene_to_packed(
			ResourceLoader.load_threaded_get(scene_path)
		)
