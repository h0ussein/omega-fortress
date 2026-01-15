# Base.gd
extends StaticBody2D

@export var max_health: float = 1000.0
var health: float = 1000.0

@onready var health_bar = $HealthBar

func _ready():
	add_to_group("base")
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health

func take_damage_base(amount: float):
	health -= amount
	
	# Update health bar
	if health_bar:
		health_bar.value = health
	
	if health <= 0:
		game_over()

func game_over():
	print("Base destroyed! Game Over!")
	# Implement game over logic here
