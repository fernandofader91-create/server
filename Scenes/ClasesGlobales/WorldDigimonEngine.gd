extends Node
class_name WorldDigimonEngine

#region UPDATE SYSTEMS
static func update_all_systems(enemy: Node, delta: float) -> void:
	if not is_instance_valid(enemy): return
	if enemy.current_state != enemy.State.RETURN and enemy.current_state != enemy.State.DEAD:
		_process_enemy_perception(enemy)
	update_regen_system(enemy, delta)
	update_state_system(enemy, delta)
	update_sync_system(enemy)
#endregion

#region REGEN SYSTEM
static func update_regen_system(enemy: Node, delta: float) -> void:
	if enemy.current_state != enemy.State.DEAD:
		_process_enemy_regen(enemy, delta)

static func _process_enemy_regen(enemy: Node, delta: float) -> void:
	enemy.regen_accumulator += delta
	if enemy.regen_accumulator >= 1.0:
		if enemy.dict_state["HP"] >= 1.0:
			var stats = enemy.dict_data["stats"]
			if enemy.dict_state["HP"] < stats["MHealth"]:
				enemy.dict_state["HP"] = min(enemy.dict_state["HP"] + stats["HealthR"], stats["MHealth"])
		enemy.regen_accumulator = 0.0
#endregion

#region STATE SYSTEM
static func update_state_system(enemy: Node, delta: float) -> void:
	match enemy.current_state:
		enemy.State.IDLE:
			_process_enemy_idle_state(enemy, delta)
		enemy.State.WANDER:
			_process_enemy_wander_state(enemy, delta)
		enemy.State.CHASE:
			_process_enemy_chase_state(enemy, delta)
		enemy.State.ARENA:
			_process_enemy_arena_state(enemy, delta)
		enemy.State.ATTACK:
			_process_enemy_attack_state(enemy, delta)
		enemy.State.RETURN:
			_process_enemy_return_state(enemy, delta)
		enemy.State.DEAD:
			_process_enemy_dead_state(enemy, delta)
#endregion

#region IDLE STATE
static func _process_enemy_idle_state(enemy: Node, delta: float) -> void:
	enemy.velocity = Vector2.ZERO
	
	enemy.state_timer -= delta
	if enemy.state_timer <= 0: 
		var limit = 150.0
		var target = enemy.spawn_position + Vector2(
			randf_range(-limit, limit), 
			randf_range(-limit, limit)
		)
		enemy.nav_agent.target_position = target
		set_enemy_wander(enemy)
#endregion

#region WANDER STATE
static func _process_enemy_wander_state(enemy: Node, delta: float) -> void:
	if enemy.nav_agent.is_navigation_finished():
		enemy.velocity = Vector2.ZERO
		return

	var next_path_pos = enemy.nav_agent.get_next_path_position()
	var dir = enemy.global_position.direction_to(next_path_pos).normalized()
	enemy.animation_vector = dir
	
	var speed = enemy.dict_state["S"]
	var intended_velocity = dir * speed
	
	if enemy.nav_agent.avoidance_enabled:
		enemy.nav_agent.set_velocity(intended_velocity)
	else:
		enemy.velocity = intended_velocity
	
	enemy.move_and_slide()
	
	if enemy.nav_agent.is_navigation_finished():
		set_enemy_idle(enemy)
		enemy.state_timer = randf_range(2.0, 4.0)
#endregion

#region DEAD STATE
#region DEAD STATE
static func _process_enemy_dead_state(enemy: Node, delta: float) -> void:
	# 1. Detener cualquier movimiento
	enemy.velocity = Vector2.ZERO
	
	# 2. Inicializar timer de muerte si no existe
	if not enemy.has_meta("dead_timer"):
		enemy.set_meta("dead_timer", 0.0)
		print("☠️ Enemigo ", enemy.dict_state["id"], " entró en estado DEAD")
	
	# 3. Contar tiempo muerto
	var dead_timer = enemy.get_meta("dead_timer", 0.0) + delta
	enemy.set_meta("dead_timer", dead_timer)
	
	# 4. Después de 3 segundos, eliminar del mapa
	if dead_timer >= 3.0:
		_notify_enemy_death(enemy)

static func _notify_enemy_death(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	
	# 1. Detener procesos INMEDIATAMENTE
	enemy.set_physics_process(false)
	enemy.set_process(false)
	
	# 2. Obtener datos
	var enemy_id = enemy.dict_state.get("id", -1)
	var zone_name = enemy.dict_data.get("zone_name", "")
	var map_node = enemy.map_reference
	# 5. Esperar OTRO frame y eliminar nodo
	await enemy.get_tree().process_frame
	if is_instance_valid(enemy):
		enemy.queue_free()
		print("🗑️ Nodo eliminado")
		
	print("💀 MURIENDO ENEMIGO ", enemy_id)
	
	# 3. ESPERAR UN FRAME ANTES DE NADA
	await enemy.get_tree().process_frame
	
	# 4. Limpiar del mapa CON RETRASO
	if enemy_id != -1 and zone_name != "" and is_instance_valid(map_node):
		# ESPERAR UN POCO MÁS
		#await Engine.get_main_loop().get_tree().create_timer(0.5).timeout
		
		WorldMapEngine._release_enemy_slot(
			enemy_id, 
			zone_name, 
			map_node.zones_data, 
			map_node.enemy_list, 
			map_node.enemy_states
		)
		
		# LIMPIEZA EXTRA: Si todavía está en enemy_states, FORZAR eliminación
		if str(enemy_id) in map_node.enemy_states:
			print("⚠️ FORZANDO eliminación de enemy_states para ", enemy_id)
			map_node.enemy_states.erase(str(enemy_id))
	



#endregion






#region CHASE STATE
static func _process_enemy_chase_state(enemy: Node, delta: float) -> void:
	# VALIDACIÓN INMEDIATA: ¿Target en ARENA?
	if is_instance_valid(enemy.target_node):
		if enemy.target_node.current_state == enemy.target_node.State.ARENA:
			enemy.target_node = null
			set_enemy_return(enemy)
			return
	
	# 1. Validación de objetivo vivo
	if not is_instance_valid(enemy.target_node) or BLB.is_entity_dead(enemy.target_node):
		enemy.target_node = null
		set_enemy_return(enemy)
		return

	# 2. Validación de distancia máxima desde spawn
	var dist_from_spawn = enemy.global_position.distance_to(enemy.spawn_position)
	var max_chase = enemy.dict_data["ai_config"]["max_chase_distance"]
	
	if dist_from_spawn > max_chase:
		enemy.target_node = null
		set_enemy_return(enemy)
		return

	# 3. Validar que no se haya escapado
	var agro_range = 128.0
	var dist_to_target = enemy.global_position.distance_to(enemy.target_node.global_position)
	
	if dist_to_target > agro_range * 1.5:
		enemy.target_node = null
		set_enemy_return(enemy)
		return

	# 4. Lógica de ataque o movimiento
	var atk_range = 16
	
	if dist_to_target <= atk_range:
		print("🎯 [CHASE] Enemy ", enemy.enemy_id, " alcanzó a ", enemy.target_node.nickname)
		
		# EVALUAR SI EL TARGET TIENE DIGIMONS VIVOS
		var first_digimon = enemy.target_node.container_reference.get_first_digimon()
		if first_digimon:
			var digimon_hp = first_digimon["stats"]["hp"]
			if digimon_hp > 0:
				# Intentar iniciar arena directamente
				var arena_started = ArenaPveEngine.start_arena_pve(enemy, enemy.target_node)
				
				if arena_started:
					enemy.velocity = Vector2.ZERO
				else:
					enemy.state_timer = 1.0
			else:
				set_enemy_attack(enemy)
		
	else:
		# Movimiento hacia el target
		enemy.nav_agent.target_position = enemy.target_node.global_position
		
		if enemy.nav_agent.is_navigation_finished():
			enemy.velocity = enemy.velocity.lerp(Vector2.ZERO, 0.2)
			return

		var next_path_pos = enemy.nav_agent.get_next_path_position()
		var dir = enemy.global_position.direction_to(next_path_pos).normalized()
		enemy.animation_vector = dir
		
		var speed = enemy.dict_state["S"]
		var intended_velocity = dir * speed
		
		if enemy.nav_agent.avoidance_enabled:
			enemy.nav_agent.set_velocity(intended_velocity)
		else:
			enemy.velocity = intended_velocity
		
		enemy.move_and_slide()
#endregion

#region ARENA STATE
static func _process_enemy_arena_state(enemy: Node, delta: float) -> void:
	# 1. Validar que el target aún existe
	if not is_instance_valid(enemy.target_node):
		set_enemy_return(enemy)
		return
	
	# 2. Verificar que el jugador no esté ya en arena
	if BLB.is_entity_in_arena(enemy.target_node):
		enemy.state_timer = 1.0
		enemy.state_timer -= delta
		return
	
	# 3. Intentar iniciar la arena
	var success = ArenaPveEngine.start_arena_pve(enemy, enemy.target_node)
	
	if success:
		enemy.velocity = Vector2.ZERO
	else:
		set_enemy_chase(enemy)
#endregion

#region ATTACK STATE 0.3,
static func _process_enemy_attack_state(enemy: Node, delta: float) -> void:
	# 1. Verificar que el target aún exista
	if not is_instance_valid(enemy.target_node):
		enemy.target_node = null
		set_enemy_return(enemy)
		return
	
	# 2. Verificar que el target NO esté en arena
	if enemy.target_node.current_state == enemy.target_node.State.ARENA:
		enemy.target_node = null
		set_enemy_return(enemy)
		return
	
	# 3. VERIFICAR DISTANCIA CONTINUAMENTE
	var agro_range = 128.0
	var atk_range = 16.0
	var dist = enemy.global_position.distance_to(enemy.target_node.global_position)
	
	if dist > atk_range:
		set_enemy_chase(enemy)
		return
	
	if dist > agro_range:
		enemy.target_node = null
		set_enemy_return(enemy)
		return
	
	# 4. Obtener container del jugador
	var gs = BLB.get_gameserver()
	var player_id = int(str(enemy.target_node.name))
	var player_container = BLB.get_player_container(player_id, gs)
	
	if not player_container:
		enemy.target_node = null
		set_enemy_return(enemy)
		return
	
	# 5. Timer de ataque
	enemy.state_timer -= delta
	if enemy.state_timer <= 0:
		var damage = enemy.dict_data["stats"].get("PAtk", 5)
		print("[ATTACK] Atacando jugador ", enemy.target_node.name, " por ", damage, " daño")
		
		var current_hp = player_container.stats["Health"]
		var new_hp = max(0, current_hp - damage)
		player_container.stats["Health"] = new_hp
		
		# 6. Si el jugador murió
		if new_hp <= 0:
			var dead_player = enemy.target_node
			dead_player.current_state = dead_player.State.DEAD
			PlayerEngine.handle_player_death(dead_player, gs)
			enemy.target_node = null
			set_enemy_return(enemy)
			return

		# 7. Resetear timer
		enemy.state_timer = 1.5
#endregion

#region RETURN STATE
static func _process_enemy_return_state(enemy: Node, delta: float) -> void:
	enemy.nav_agent.target_position = enemy.spawn_position
	
	if enemy.nav_agent.is_navigation_finished():
		var dist_to_spawn = enemy.global_position.distance_to(enemy.spawn_position)
		if dist_to_spawn < 20.0:
			set_enemy_idle(enemy)
			enemy.state_timer = randf_range(2.0, 4.0)
			enemy.velocity = Vector2.ZERO
		return

	var next_path_pos = enemy.nav_agent.get_next_path_position()
	var dir = enemy.global_position.direction_to(next_path_pos).normalized()
	enemy.animation_vector = dir
	
	var speed = enemy.dict_state["S"]
	var intended_velocity = dir * speed
	
	if enemy.nav_agent.avoidance_enabled:
		enemy.nav_agent.set_velocity(intended_velocity)
	else:
		enemy.velocity = intended_velocity
	
	enemy.move_and_slide()
#endregion

#region STATE SETTERS
static func set_enemy_idle(enemy: Node) -> void:
	if enemy.current_state != enemy.State.DEAD:
		enemy.current_state = enemy.State.IDLE
		enemy.velocity = Vector2.ZERO

static func set_enemy_wander(enemy: Node) -> void:
	if enemy.current_state != enemy.State.DEAD:
		enemy.current_state = enemy.State.WANDER

static func set_enemy_chase(enemy: Node) -> void:
	if enemy.current_state == enemy.State.CHASE:
		return
	
	if enemy.current_state != enemy.State.DEAD:
		enemy.current_state = enemy.State.CHASE

static func set_enemy_arena(enemy: Node) -> void:
	if enemy.current_state != enemy.State.DEAD:
		enemy.current_state = enemy.State.ARENA

static func set_enemy_attack(enemy: Node) -> void:
	if enemy.current_state != enemy.State.DEAD:
		enemy.current_state = enemy.State.ATTACK

static func set_enemy_return(enemy: Node) -> void:
	if enemy.current_state != enemy.State.DEAD:
		enemy.current_state = enemy.State.RETURN

static func set_enemy_dead(enemy: Node) -> void:
	enemy.current_state = enemy.State.DEAD
#endregion

#region SYNC SYSTEM
static func update_sync_system(enemy):
	if not is_instance_valid(enemy): return
	
	var state = enemy.dict_state
	state["Px"] = enemy.global_position.x
	state["Py"] = enemy.global_position.y
	state["ST"] = enemy.State.keys()[enemy.current_state].to_lower()
	state["T"] = Time.get_ticks_msec()
	state["A"] = enemy.animation_vector
	
	if enemy.map_reference:
		enemy.map_reference.ReceiveEnemyState(state, str(state["id"]))
#endregion

#region PERCEPTION SYSTEM
static func _process_enemy_perception(enemy: Node) -> void:
	var agro_range = 128.0
	
	var enemy_map = enemy.dict_state.get("M", "")
	if enemy_map == "":
		return
	
	# Caso A: Evaluando target actual
	if is_instance_valid(enemy.target_node):
		var dist = enemy.global_position.distance_to(enemy.target_node.global_position)
		
		if dist > agro_range * 1.5: 
			enemy.target_node = null
			set_enemy_return(enemy)
			return

		if BLB.is_entity_dead(enemy.target_node):
			enemy.target_node = null
			set_enemy_return(enemy)
			return
			
		if enemy.target_node.current_state == enemy.target_node.State.ARENA:
			enemy.target_node = null
			set_enemy_return(enemy)
			return
	
	# Caso B: Búsqueda de nuevo target
	if enemy.target_node == null:
		var players_in_same_map = BLB.get_players_in_map(enemy_map)
		
		for player in players_in_same_map:
			if not is_instance_valid(player):
				continue
			
			if player.current_state == player.State.DEAD: 
				continue
			
			if player.current_state == player.State.ARENA:
				continue
			
			var dist = enemy.global_position.distance_to(player.global_position)
			
			if dist < agro_range and not BLB.is_entity_dead(player):
				enemy.target_node = player
				set_enemy_chase(enemy)
				break
#endregion
