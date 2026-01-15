extends Node

# This script can be attached to any node to help debug boss-related issues

func _ready():
	print("DEBUG_BOSS: Debug script initialized")
	
	# Connect to wave manager signals
	var wave_managers = get_tree().get_nodes_in_group("wave_manager")
	if wave_managers.size() > 0:
		var wave_manager = wave_managers[0]
		wave_manager.wave_started.connect(_on_wave_started)
		wave_manager.boss_wave_started.connect(_on_boss_wave_started)
		wave_manager.enemy_spawned.connect(_on_enemy_spawned)
		print("DEBUG_BOSS: Connected to wave manager signals")
	else:
		print("DEBUG_BOSS: No wave manager found!")

func _on_wave_started(wave_number):
	print("DEBUG_BOSS: Wave " + str(wave_number) + " started")
	
	# Check if this is a boss wave
	var wave_managers = get_tree().get_nodes_in_group("wave_manager")
	if wave_managers.size() > 0:
		var wave_manager = wave_managers[0]
		if wave_manager.is_boss_wave():
			print("DEBUG_BOSS: This is a boss wave!")
		else:
			print("DEBUG_BOSS: This is a regular wave")

func _on_boss_wave_started(wave_number):
	print("DEBUG_BOSS: BOSS WAVE " + str(wave_number) + " STARTED!")

func _on_enemy_spawned(enemy):
	if "is_boss" in enemy and enemy.is_boss:
		print("DEBUG_BOSS: Boss enemy spawned: " + enemy.name)
		print("DEBUG_BOSS: Boss position: " + str(enemy.global_position))
		print("DEBUG_BOSS: Boss health: " + str(enemy.health) + "/" + str(enemy.max_health))
		
		# Check if all required nodes exist
		var required_nodes = ["Visuals", "AttackArea", "CollisionShape2D", "BossHealthBar"]
		for node_name in required_nodes:
			if enemy.has_node(node_name):
				print("DEBUG_BOSS: Node '" + node_name + "' exists")
			else:
				print("DEBUG_BOSS: ERROR - Node '" + node_name + "' is missing!")
		
		# Check if all required timers exist
		var required_timers = ["AttackHero", "AttackBase", "SpecialAttack", "SpecialWarningTimer"]
		for timer_name in required_timers:
			if enemy.has_node(timer_name):
				print("DEBUG_BOSS: Timer '" + timer_name + "' exists")
			else:
				print("DEBUG_BOSS: ERROR - Timer '" + timer_name + "' is missing!")
