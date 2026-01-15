# BarrierButton.gd
extends Button

@onready var barrier_placer = get_node_or_null("/root/Node2D_main/BarrierPlacer")

func _ready():
	pressed.connect(_on_pressed)
	print("BarrierButton: Ready")

func _on_pressed():
	if barrier_placer:
		barrier_placer.start_placing_barriers()
		print("BarrierButton: Started barrier placement mode")
	else:
		print("BarrierButton: Could not find BarrierPlacer node")
