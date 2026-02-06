extends Node
class_name WorldMapEngine

#region MAP SETUP
static func setup_map(map_node: Node) -> void:
	print("SETUP DEL MAPA ",map_node.name)
	"""
	Configuración completa del mapa.
	"""
	# 1. Setup de zonas
	if map_node.has_node("Node/Positional"):
		map_node.zones_data = _setup_zones_internal(map_node.get_node("Node/Positional"), map_node.zone_configs)
	else:
		print("[MapEngine] ERROR: Mapa ", map_node.name, " no tiene nodo Positional")
		return
	
	# 2. Configurar timer de spawn
	_setup_spawn_timer(map_node)
	
	print("[MapEngine] Mapa ", map_node.name, " configurado")

static func _setup_zones_internal(positional_node: Node2D, configs: Dictionary) -> Dictionary:
	print("?")
	"""
	Configura las zonas de spawn del mapa.
	"""
	var zones_output = {}
	if not positional_node: 
		return zones_output
		
	for zone_node in positional_node.get_children():
		var zone_name = zone_node.name
		if configs.has(zone_name):
			var points = []
			for marker in zone_node.get_children():
				if marker is Marker2D: 
					points.append(marker.global_position)
			
			zones_output[zone_name] = {
				"points": points, 
				"open_locations": range(points.size()),
				"occupied_slots": {}, 
				"current_count": 0
			}
	return zones_output

static func _setup_spawn_timer(map_node: Node) -> void:
	"""
	Crea timer de spawn para el mapa.
	"""
	var timer = Timer.new()
	timer.name = "SpawnTimer"
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_on_spawn_timer_timeout.bind(map_node))
	map_node.add_child(timer)
#endregion

#region ENEMY SPAWNING
static func _on_spawn_timer_timeout(map_node: Node) -> void:
	"""
	Timer callback: intenta spawnear enemigos.
	"""
	if map_node.enemy_list.size() >= map_node.enemy_maximum: 
		return
	
	for zone_name in map_node.zone_configs.keys():
		_spawn_enemy_in_zone(map_node, zone_name)

static func _spawn_enemy_in_zone(map_node: Node, zone_name: String) -> void:
	var full_db_data = ServerData.world_enemies_data[0] 
	var result = _register_enemy_spawn(
		map_node.enemy_id_counter, 
		zone_name, 
		map_node.zones_data, 
		map_node.zone_configs[zone_name], 
		map_node.map_id, 
		full_db_data["stats"]
	)
	
	if result.is_empty(): 
		return

	var id_str = str(map_node.enemy_id_counter)
	map_node.enemy_list[map_node.enemy_id_counter] = result["type"]
	map_node.enemy_states[id_str] = result["state"]
	
	_instance_enemy_node(map_node, id_str, result["pos"], zone_name, result["state"], result["raw_data"])
	map_node.enemy_id_counter += 1

static func _register_enemy_spawn(enemy_id: int, zone_name: String, zones_data: Dictionary, 
								 zone_config: Dictionary, map_id: String, raw_stats: Dictionary) -> Dictionary:
	"""
	Registra un spawn de enemigo en una zona.
	"""
	if not zones_data.has(zone_name):
		return {}
		
	var data = zones_data[zone_name]
	if data["current_count"] >= zone_config["max_enemies"] or data["open_locations"].is_empty():
		return {}
	
	# Elegir posición aleatoria
	var rng_idx = randi() % data["open_locations"].size()
	var pos_idx = data["open_locations"][rng_idx]
	var pos = data["points"][pos_idx]
	
	# Marcar como ocupado
	data["open_locations"].remove_at(rng_idx)
	data["occupied_slots"][enemy_id] = pos_idx
	data["current_count"] += 1
	
	# Configurar AI
	var ai_config_merge = ServerData.world_enemies_data[0]["ai_config"].duplicate()
	for key in zone_config.keys():
		ai_config_merge[key] = zone_config[key]
	
	# Elegir tipo
	var type = zone_config["types"].pick_random()
	
	# Crear estado de red
	var state = {
		"id": enemy_id, "N": type, "M": map_id, "Px": pos.x, "Py": pos.y,
		"S": raw_stats.get("Speed", 100),
		"AS": raw_stats.get("ASpeed", 1.0),
		"HP": raw_stats["Health"], "MHP": raw_stats["MHealth"],
		"MP": raw_stats["Mana"], "MMP": raw_stats["MMana"],
		"ST": "idle", "A": Vector2.ZERO, "T": Time.get_ticks_msec()
	}
	
	# Datos para el nodo
	var raw_data = {
		"zone_name": zone_name,
		"stats": raw_stats,
		"ai_config": ai_config_merge 
	}
	
	return {"state": state, "pos": pos, "type": type, "raw_data": raw_data}

static func _instance_enemy_node(map_node: Node, enemy_id: String, position: Vector2, 
								zone_name: String, net_state: Dictionary, db_data: Dictionary) -> void:
	var enemy_scene = preload("res://Scenes/Enemies/ServerWorldDigimon.tscn")
	var new_enemy = enemy_scene.instantiate()
	
	new_enemy.name = enemy_id
	new_enemy.global_position = position
	new_enemy.map_reference = map_node
	new_enemy.enemy_died.connect(_on_enemy_died.bind(map_node, zone_name))
	
	map_node.get_node("Node/Enemies").add_child(new_enemy)
	
	if new_enemy.has_method("setup_enemy"):
		new_enemy.setup_enemy(net_state, db_data)

static func _on_enemy_died(map_node: Node, zone_name: String, enemy_id: int) -> void:
	_release_enemy_slot(enemy_id, zone_name, map_node.zones_data, map_node.enemy_list, map_node.enemy_states)
	
	var enemy_node = map_node.get_node_or_null("Node/Enemies/" + str(enemy_id))
	if enemy_node:
		enemy_node.queue_free()

static func _release_enemy_slot(enemy_id: int, zone_name: String, zones_data: Dictionary, 
							   enemy_list: Dictionary, enemy_states: Dictionary) -> void:
	"""
	Libera el slot de un enemigo.
	"""
	if zones_data.has(zone_name):
		var z_data = zones_data[zone_name]
		if z_data["occupied_slots"].has(enemy_id):
			z_data["open_locations"].append(z_data["occupied_slots"][enemy_id])
			z_data["occupied_slots"].erase(enemy_id)
			z_data["current_count"] = max(0, z_data["current_count"] - 1)
	
	enemy_list.erase(enemy_id)
	enemy_states.erase(str(enemy_id))
#endregion

#region PLAYER MANAGEMENT
static func register_player_in_map(player_id: int, player_container) -> Dictionary:
	print("register player in map timestamp: ", Time.get_ticks_msec())
	var stats = player_container.stats
	var state = {
		"id": player_id, 
		"N": player_container.nombre, 
		"Px": stats["Px"], 
		"Py": stats["Py"],
		"HP": stats["Health"], 
		"MHP": stats["MHealth"],
		"MP": stats["Mana"], 
		"MMP": stats["MMana"],
		"S": stats["Speed"], 
		"ST": "idle", 
		"A": Vector2.DOWN, 
		"T": Time.get_ticks_msec()
	}
	
	var data = stats.duplicate()
	data["N"] = player_container.nombre
	
	return {"state": state, "data": data}

static func release_player(player_id: int, player_states: Dictionary) -> void:
	print("ANTES DE LA MENTIRA", player_states)
	player_states.erase(str(player_id))
	print("🗑️ WORLD_MAP: Jugador ", player_id, " eliminado TIMESTAMP: ",Time.get_ticks_msec())
	print("ME RE MIENTE", player_states)




static func setup_player_node_pos(player_node: Node, player_container) -> void:
	"""
	Configura la posición inicial del jugador.
	"""
	if not is_instance_valid(player_node) or not is_instance_valid(player_container):
		return

	var spawn_x = player_container.stats.get("Px", 0.0)
	var spawn_y = player_container.stats.get("Py", 0.0)
	player_node.global_position = Vector2(spawn_x, spawn_y)
#endregion

#region MAP DATA & SYNC
static func collect_map_data(enemy_states: Dictionary, player_states: Dictionary) -> void:
	"""
	Procesa los datos del mapa (para sync, broadcast, etc.)
	"""
	var map_data = {
		"enemies": enemy_states,
		"players": player_states,
		"timestamp": Time.get_ticks_msec()
	}
	
	# Aquí podrías hacer broadcast o logging
	# _broadcast_to_clients(map_data)

static func get_map_node(map_name: String, game_server: Node) -> Node:
	"""
	Obtiene un nodo de mapa desde el GameServer.
	"""
	return game_server.get_node_or_null("ContainerMaps/" + map_name)
#endregion

#region WORLD STATE GENERATION
static func generate_world_state(game_server: Node) -> Dictionary:
	"""
	Genera el world_state completo con todos los mapas.
	Formato: {"T": timestamp, "Mapa1": {...}, "Mapa2": {...}, ...}
	"""
	var world_state = {}
	world_state["T"] = Time.get_ticks_msec()
	
	var container_maps = game_server.get_node("ContainerMaps")
	
	for map_node in container_maps.get_children():
		# Acceso directo a las variables (ya están definidas en BaseMap)
		world_state[map_node.name] = {
			"enemies": map_node.enemy_states,  # {} si está vacío
			"players": map_node.player_states   # {} si está vacío
		}
	
	return world_state
#endregion






static func add_player_to_map(player_id: int, player_container, map_node) -> void:
	print("🗺️ ADD_PLAYER_TO_MAP: ", player_id, "map_name ",map_node.name)
	
	# 1. Crear estado del jugador
	var state = _create_player_state(player_id, player_container)
	var data = player_container.stats.duplicate()
	data["N"] = player_container.nombre
	
	# 2. Agregar al diccionario del mapa
	map_node.player_states[str(player_id)] = state
	
	# 3. Instanciar nodo player
	var player_scene = preload("res://Scenes/NPCS/ServerPlayer.tscn")
	var new_player = player_scene.instantiate()
	new_player.name = str(player_id)
	new_player.container_reference = player_container
	new_player.map_reference = map_node
	
	# 4. Posicionar
	new_player.global_position = Vector2(
		player_container.stats.get("Px", 0.0),
		player_container.stats.get("Py", 0.0)
	)
	
	# 5. Agregar al árbol (SIN call_deferred)
	map_node.get_node("Node/Players").call_deferred("add_child", new_player)
	
	# 6. Setup del nodo (si tiene método)
	if new_player.has_method("setup_player"):
		new_player.setup_player(state, data)
	
	print("✅ ADD_PLAYER_TO_MAP completado: ", player_id)

static func _create_player_state(player_id: int, player_container) -> Dictionary:
	"""Crea el diccionario de estado para un jugador."""
	var stats = player_container.stats
	return {
		"id": player_id,
		"N": player_container.nombre,
		"Px": stats["Px"],
		"Py": stats["Py"],
		"HP": stats["Health"],
		"MHP": stats["MHealth"],
		"MP": stats["Mana"],
		"MMP": stats["MMana"],
		"S": stats["Speed"],
		"ST": "idle",
		"A": Vector2.DOWN,
		"T": Time.get_ticks_msec()
	}

static func remove_player_from_map(player_id: int, map_node) -> void:
	print("🗑️ REMOVE_PLAYER_FROM_MAP: ", player_id)
	
	# 1. Eliminar nodo player PRIMERO
	var player_node = map_node.get_node_or_null("Node/Players/" + str(player_id))
	if player_node and is_instance_valid(player_node):
		player_node.set_physics_process(false)
		
		player_node.map_reference = null 
		player_node.container_reference = null 
		player_node.queue_free()
		print("🗑️ Nodo player eliminado")
	
	# 2. Eliminar de player_states DESPUÉS
	if map_node.player_states.has(str(player_id)):
		map_node.player_states.erase(str(player_id))
		print("🧹 Eliminado de player_states")
	
	print("✅ REMOVE_PLAYER_FROM_MAP completado: ", player_id)
