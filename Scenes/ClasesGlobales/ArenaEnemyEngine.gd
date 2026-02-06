extends Node
class_name ArenaEnemyEngine

#region UPDATE SYSTEMS
static func update_all_systems(enemy: Node, delta: float) -> void:
	if not is_instance_valid(enemy):
		return
	
	_process_ai(enemy, delta)
	
	if enemy.current_state != enemy.State.RETURN and enemy.current_state != enemy.State.DEAD:
		_seek_player(enemy)
	
	_update_sync_to_arena(enemy)
#endregion

#region AI SYSTEM
static func _process_ai(enemy: Node, delta: float) -> void:
	match enemy.current_state:
		enemy.State.IDLE:
			_process_idle_state(enemy, delta)
		enemy.State.WANDER:
			_process_wander_state(enemy, delta)
		enemy.State.CHASE:
			_process_chase_state(enemy, delta)
		enemy.State.ATTACK:
			_process_attack_state(enemy, delta)
		enemy.State.RETURN:
			_process_return_state(enemy, delta)

static func _process_idle_state(enemy: Node, delta: float) -> void:
	enemy.velocity = enemy.velocity.lerp(Vector2.ZERO, 0.2)
	enemy.state_timer -= delta
	if enemy.state_timer <= 0: 
		var limit = 300.0
		var target = enemy.spawn_position + Vector2(
			randf_range(-limit, limit), 
			randf_range(-limit, limit)
		)
		enemy.nav_agent.target_position = target
		_change_state(enemy, enemy.State.WANDER)

static func _process_wander_state(enemy: Node, delta: float) -> void:
	if enemy.nav_agent.is_navigation_finished():
		enemy.velocity = enemy.velocity.lerp(Vector2.ZERO, 0.2)
		return

	var next_path_pos = enemy.nav_agent.get_next_path_position()
	var dir = enemy.global_position.direction_to(next_path_pos).normalized()
	enemy.animation_vector = dir
	
	var speed = enemy.enemy_state["Speed"]
	var intended_velocity = dir * speed
	
	if enemy.nav_agent.avoidance_enabled:
		enemy.nav_agent.set_velocity(intended_velocity)
	else:
		enemy.velocity = intended_velocity
	
	enemy.move_and_slide()
	
	if enemy.nav_agent.is_navigation_finished():
		_change_state(enemy, enemy.State.IDLE)
		enemy.state_timer = randf_range(2.0, 4.0)

static func _process_chase_state(enemy: Node, delta: float) -> void:
	if not is_instance_valid(enemy.chase_target):
		enemy.chase_target = null
		_change_state(enemy, enemy.State.RETURN)
		return

	var dist_to_target = enemy.global_position.distance_to(enemy.chase_target.global_position)
	var atk_range = 16.0
	
	if dist_to_target <= atk_range:
		_change_state(enemy, enemy.State.ATTACK)
	else:
		enemy.nav_agent.target_position = enemy.chase_target.global_position
		
		if enemy.nav_agent.is_navigation_finished():
			enemy.velocity = enemy.velocity.lerp(Vector2.ZERO, 0.2)
			return

		var next_path_pos = enemy.nav_agent.get_next_path_position()
		var dir = enemy.global_position.direction_to(next_path_pos).normalized()
		enemy.animation_vector = dir
		
		var speed = enemy.enemy_state["Speed"]
		var intended_velocity = dir * speed
		
		if enemy.nav_agent.avoidance_enabled:
			enemy.nav_agent.set_velocity(intended_velocity)
		else:
			enemy.velocity = intended_velocity
		
		enemy.move_and_slide()

static func _process_attack_state(enemy: Node, delta: float) -> void:
	enemy.state_timer -= delta
	if enemy.state_timer <= 0:
		_execute_attack_logic(enemy)
		_change_state(enemy, enemy.State.CHASE)

static func _process_return_state(enemy: Node, delta: float) -> void:
	enemy.nav_agent.target_position = enemy.spawn_position
	
	if enemy.nav_agent.is_navigation_finished():
		var dist_to_spawn = enemy.global_position.distance_to(enemy.spawn_position)
		if dist_to_spawn < 20.0:
			_change_state(enemy, enemy.State.IDLE)
			enemy.state_timer = randf_range(2.0, 4.0)
			enemy.velocity = Vector2.ZERO
		return

	var next_path_pos = enemy.nav_agent.get_next_path_position()
	var dir = enemy.global_position.direction_to(next_path_pos).normalized()
	enemy.animation_vector = dir
	
	var speed = enemy.enemy_state["Speed"]
	var intended_velocity = dir * speed
	
	if enemy.nav_agent.avoidance_enabled:
		enemy.nav_agent.set_velocity(intended_velocity)
	else:
		enemy.velocity = intended_velocity
	
	enemy.move_and_slide()
#endregion

#region STATE MANAGEMENT
static func _change_state(enemy: Node, new_state: int) -> void:
	if enemy.current_state == new_state and new_state != enemy.State.IDLE and new_state != enemy.State.CHASE: 
		return
	
	enemy.current_state = new_state
	
	match new_state:
		enemy.State.IDLE:
			enemy.chase_target = null
			enemy.state_timer = randf_range(2.0, 5.0)
			enemy.velocity = Vector2.ZERO
			
		enemy.State.WANDER:
			enemy.state_timer = 8.0
			
		enemy.State.CHASE:
			enemy.state_timer = 0.5
			enemy.velocity = Vector2.ZERO
			
		enemy.State.RETURN:
			enemy.chase_target = null
			
		enemy.State.ATTACK:
			enemy.state_timer = 1.0
#endregion

#region PLAYER DETECTION
static func _seek_player(enemy: Node) -> void:
	var agro_range = 400.0
	var escape_range = 600.0
	
	if is_instance_valid(enemy.chase_target):
		var dist = enemy.global_position.distance_to(enemy.chase_target.global_position)
		
		if dist > escape_range: 
			enemy.chase_target = null
			_change_state(enemy, enemy.State.RETURN)
			return
	
	if enemy.chase_target == null:
		if is_instance_valid(enemy.map_reference):
			var arena_id = enemy.map_reference.name
			var players = BLB.get_players_in_arena(arena_id)
			
			for player in players:
				if not is_instance_valid(player):
					continue
				
				var dist = enemy.global_position.distance_to(player.global_position)
				
				if dist < agro_range:
					enemy.chase_target = player
					_change_state(enemy, enemy.State.CHASE)
					break

static func _check_recovery_during_return(enemy: Node) -> void:
	var agro_range = 400.0
	
	if enemy.has("map_reference") and is_instance_valid(enemy.map_reference):
		var arena_id = enemy.map_reference.name
		var players = BLB.get_players_in_arena(arena_id)
		
		for player in players:
			if not is_instance_valid(player):
				continue
			
			var dist = enemy.global_position.distance_to(player.global_position)
			
			if dist < agro_range:
				enemy.chase_target = player
				_change_state(enemy, enemy.State.CHASE)
				return
#endregion

#region ATTACK SYSTEM
static func _execute_attack_logic(enemy: Node):
	if not is_instance_valid(enemy.chase_target):
		return

	var aspeed = int(enemy.enemy_state.get("ASpeed", 100))
	var cooldown_real = 2
	enemy.state_timer = cooldown_real

	var damage = enemy.enemy_state.get("PAtk", 10)
	if enemy.chase_target.has_method("ReceiveDamage"):
		enemy.chase_target.ReceiveDamage(enemy.enemy_id, damage)



static func take_damage(enemy: Node, player_id: String, skill_damage: int) -> void:
	print("🔥 ENGINE DAÑO | Enemigo:", enemy.name)
	print("   enemy_state keys:", enemy.enemy_state.keys())
	print("   Health value:", enemy.enemy_state.get("Health", "NO-EXISTE"))
	
	# Restar el daño directamente al enemigo
	var damage = int(skill_damage)
	enemy.enemy_state["Health"] -= damage
	
	print("   Damage aplicado:", damage)
	print("   Health DESPUÉS:", enemy.enemy_state["Health"])
	
	# Mostrar el popup de daño
	var data = [enemy.global_position, damage, enemy.map_reference]
	BLB.get_gameserver().ServerSendToAllClients("DamagePopUp", data)
	
	# Verificar si murió
	if enemy.enemy_state["Health"] <= 0:
		print("   ☠️ ENEMIGO DERROTADO")
		enemy.current_state = enemy.State.DEAD
		
		# Terminar la arena
		var arena_id = enemy.map_reference.name if enemy.map_reference else ""
		if arena_id != "" and ArenaPveEngine.active_arenas.has(arena_id):
			print("   🏆 Terminando arena - Ganador: player")
			ArenaPveEngine.end_arena_pve(arena_id, "player")



#endregion

#region SYNC SYSTEM
static func _update_sync_to_arena(enemy: Node) -> void:
	if not enemy.map_reference:
		return
	
	var target_name = enemy.chase_target.name if is_instance_valid(enemy.chase_target) else null
	
	var state = {
		"name": enemy.enemy_type,
		"Px": enemy.global_position.x,
		"Py": enemy.global_position.y,
		"spd": enemy.enemy_state.get("Speed", 100),
		"M": enemy.enemy_state.get("M", ""),
		"atk": enemy.enemy_state.get("PAtk", 10),
		"T": Time.get_ticks_msec(),
		"HP": enemy.enemy_state.get("Health", 100),
		"maxHP": enemy.enemy_state.get("MHealth", 100),
		"state": enemy.State.keys()[enemy.current_state].to_lower(),
		"target": target_name,
		"dir": enemy.animation_vector,
		"ASpeed": enemy.enemy_state.get("ASpeed", 100)
	}
	
	enemy.map_reference.updateEnemyAIState(str(enemy.name), state)
#endregion
