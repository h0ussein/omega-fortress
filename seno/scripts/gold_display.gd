extends Control

@onready var gold_label = $GoldLabel
@onready var gold_icon = $GoldIcon

var current_gold = 0

func _ready():
	# Make sure control is set to ignore camera zoom
	set_as_top_level(true)
	
	# Initialize with zero gold
	update_gold(1000)
	
	print("GoldDisplay: Ready")

func update_gold(amount: int):
	current_gold = amount
	if gold_label:
		gold_label.text ="gold:"+ str(amount)
	
	# Update visibility of elements
	if gold_icon:
		gold_icon.visible = true
	if gold_label:
		gold_label.visible = true
	
	print("GoldDisplay: Updated to " + str(amount) + " gold")

func get_current_gold() -> int:
	return current_gold
