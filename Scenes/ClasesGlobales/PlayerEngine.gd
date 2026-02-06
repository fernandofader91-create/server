extends Node
class_name PlayerEngine

#region MAIN UPDATE
static func update_all_systems(player: Node, delta: float) -> void:
	if not is_instance_valid(player): return
	if not is_instance_valid(player.container_reference): return
	
	update_state_system(player, delta)
	update_sync_system(player)
#endregion

#region STATE SETTERS
static func set_player_idle(player: Node) -> void:
	if player.current_state == player.State.IDLE:
		return
	player.current_state = player.State.IDLE

static func set_player_move(player: Node) -> void:
	if player.current_state == player.State.MOVE:
		return
	player.current_state = player.State.MOVE

static func set_player_dead(player: Node) -> void:
	if player.current_state == player.State.DEAD:
		return
	player.current_state = player.State.DEAD

static func set_player_arena(player: Node) -> void:
	if player.current_state == player.State.ARENA:
		return
	player.current_state = player.State.ARENA
#endregion

#region STATE SYSTEM
static func update_state_system(player: Node, delta: float) -> void:
	match player.current_state:
		player.State.DEAD:
			_process_player_dead_state(player, delta)
		player.State.IDLE:
			_process_player_idle_state(player, delta)
		player.State.MOVE:
			_process_player_move_state(player, delta)
		player.State.ARENA:
			_process_player_arena_state(player, delta)
#endregion

#region MOVEMENT CHECKS
static func can_player_move(player: Node) -> bool:
	return player.current_state not in [player.State.DEAD, player.State.ARENA]
#endregion

#region INPUT MOVE

static func handle_client_mouse_request(player_id: int, request_data, game_server: Node) -> bool:
	var refs = BLB.get_references(player_id, game_server)
	if refs.is_empty(): return false
	
	var player = refs["player"]
	var target_pos = request_data[0]
	
	if BLB.is_entity_dead(player): return false
	if not can_player_move(player): return false
	
	# Set dirección de animación
	player.animation_vector = (target_pos - player.global_position).normalized()
	


	
	# Ahora asignar el nuevo target
	player.nav_agent.target_position = target_pos
	
	set_player_move(player)
	

	
	return true


#endregion

#region STATE PROCESSORS
static func _process_player_idle_state(player: Node, delta: float) -> void:
	if player.velocity.length() > 0:
		player.velocity = Vector2.ZERO

static func _process_player_move_state(player: Node, delta: float) -> void:
	var next_vel = get_next_velocity(player, player.nav_agent)
	
	player.velocity = next_vel
	player.move_and_slide()
	
	if player.velocity.length() <= 0:
		set_player_idle(player)

static func _process_player_dead_state(player: Node, delta: float) -> void:
	pass  # TODO: Implementar lógica de estado muerto

static func _process_player_arena_state(player: Node, delta: float) -> void:
	pass  # TODO: Implementar lógica de estado arena
#endregion

#region NAVIGATION
static func get_next_velocity(player: Node, agent: NavigationAgent2D) -> Vector2:
	# Si el agente dice que llegó, frenamos suavemente
	if agent.is_navigation_finished():
		return player.velocity.lerp(Vector2.ZERO, 0.2)
	
	var next_path_pos = agent.get_next_path_position()
	var dir = player.global_position.direction_to(next_path_pos)
	
	# Seteamos la dirección de la animación
	player.animation_vector = dir
	
	var speed = player.container_reference.stats["Speed"]
	var final_vel = dir * speed
	
	return final_vel
#endregion

#region SYNC STATES

static func update_sync_system(player: Node) -> void:
	if not is_instance_valid(player): return
	
	var state = player.dict_state
	var stats = player.container_reference.stats
	
	state["Px"] = player.global_position.x
	state["Py"] = player.global_position.y
	state["S"]  = stats["Speed"]
	state["HP"] = stats["Health"]
	state["MHP"] = stats["MHealth"]
	state["MP"] = stats["Mana"]
	state["MMP"] = stats["MMana"]
	state["N"]  = player.nickname
	state["T"]  = Time.get_ticks_msec()
	state["ST"] = _get_state_string(player.current_state)
	state["A"]  = player.animation_vector

	
	if player.map_reference and player.map_reference.has_method("ReceivePlayerState"):
		player.map_reference.ReceivePlayerState(state, str(player.name))

# Función helper para convertir el estado numérico a string
static func _get_state_string(current_state: int) -> String:
	match current_state:
		0: return "idle"
		1: return "move"
		2: return "dead"
		3: return "arena"
		_: return "idle"

#endregion

#region DEAD PLAYER 
static func handle_player_death(player: Node, game_server: Node) -> void:
	if not is_instance_valid(player) or not player.container_reference:
		return
	
	
	# 1. Marcar como muerto
	set_player_dead(player)
	
	# 2. Resetear HP a 0 (por si acaso)
	player.container_reference.stats["Health"] = 0
	
	# 3. Programar respawn automático después de 1 segundo
	var respawn_timer = Timer.new()
	respawn_timer.name = "RespawnTimer_" + str(player.name)
	respawn_timer.wait_time = 1.0
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(_on_player_respawn_timeout.bind(player, game_server))
	
	player.add_child(respawn_timer)
	respawn_timer.start()

static func _on_player_respawn_timeout(player: Node, game_server: Node) -> void:
	if not is_instance_valid(player):
		return

	var player_id = int(str(player.name))
	var refs = BLB.get_references(player_id, game_server)
	
	if refs.is_empty():
		return
	
	var success = await PlayerLifecycleEngine.handle_player_respawn(player_id, game_server, refs)
	
	if not success:
		pass
#endregion
