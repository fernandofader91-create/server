extends Node
class_name PlayerLifecycleEngine

#SCRIPT OPTMIZADO 100%


#region AUTHENTICATION
static func auth_start(player_id: int):
	print("🔐 AUTH_START: ", player_id)
	var gs = BLB.get_gameserver()
	gs.awaiting_verification[player_id] = {"Timestamp": Time.get_unix_time_from_system()}
	gs.ServerSendToOneClient(player_id, "FetchToken", null)

static func auth_verify(player_id: int, token: String):
	print("✅ AUTH_VERIFY: ", player_id)
	var gs = BLB.get_gameserver()
	
	for tkn in gs.expected_tokens:
		if tkn.strip_edges() == token:
			gs.awaiting_verification.erase(player_id)
			gs.expected_tokens.erase(tkn)
			return
	
	await gs.get_tree().create_timer(0.5).timeout
	
	for tkn in gs.expected_tokens:
		if tkn.strip_edges() == token:
			gs.awaiting_verification.erase(player_id)
			gs.expected_tokens.erase(tkn)
			return
	
	gs.awaiting_verification.erase(player_id)
	gs.ServerSendToOneClient(player_id, "AuthFailed", "Token inválido")
#endregion

#region CHARACTER LOADING
static func handle_load_character(player_id: int, request_data, gs: Node) -> bool:
	print("👤 LOAD_CHARACTER: ", player_id)
	var character_name = request_data[0]
	var character_data = await HttpSingleton.GetCharacterByName(character_name)
	
	if character_data == null or not validate_character_data(character_data):
		print("❌ LOAD_CHARACTER_FAILED: ", player_id)
		return false
	
	create_player_container(player_id, character_data, gs)
	connect_client_instance(player_id, gs)
	gs.ServerSendToOneClient(player_id, "LoadCharacter", character_data)
	
	return true

static func validate_character_data(data: Dictionary) -> bool:
	return data.has("stats") and data.has("name") and data["stats"].has("M")
#endregion

#region CONTAINER MANAGEMENT
static func create_player_container(player_id: int, data: Dictionary, gs: Node):
	print("📦 CREATE_CONTAINER: ", player_id)
	var player_container_scene = preload("res://Scenes/GameServer/PlayerContainer.tscn")
	var new_player_container = player_container_scene.instantiate()
	
	new_player_container.name = str(player_id)
	new_player_container.nombre = data["name"]
	new_player_container.stats = data["stats"]
	new_player_container.digimon_memory = data["digimons_memory"]
	
	gs.get_node("ContainerPlayers").add_child(new_player_container, true)
	return new_player_container
#endregion

#region NETWORK SYNC
static func handle_latency(player_id: int, client_time: int, game_server: Node) -> bool:
	var packet = [Time.get_ticks_msec(), client_time]
	game_server.ServerSendToOneClient(player_id, "Sync", packet)
	return true

static func handle_token_verification(player_id: int, token: String, game_server: Node) -> bool:
	auth_verify(player_id, token)
	return true

static func handle_time_sync(player_id: int, client_time: int, game_server: Node) -> bool:
	var packet = [Time.get_ticks_msec(), client_time]
	game_server.ServerSendToOneClient(player_id, "FetchServerTime", packet)
	return true
#endregion

#region CLIENT CONNECTION
static func connect_client_instance(player_id: int, game_server: Node) -> void:
	print("👶 CONNECT_CLIENT_INSTANCE: ", player_id)
	
	var p_container = BLB.get_player_container(player_id, game_server)
	if not p_container:
		print("❌ CONNECT_CLIENT_INSTANCE: No container")
		return
	
	var map_name = p_container.stats["M"]
	var mapa = BLB.get_map_node(map_name, game_server)
	if not mapa:
		print("❌ CONNECT_CLIENT_INSTANCE: No map")
		return
	
	WorldMapEngine.add_player_to_map(player_id, p_container, mapa)



static func disconnect_client_instance(player_id: int, game_server: Node) -> void:
	print("🔌 DISCONNECT_CLIENT_INSTANCE: ", player_id)
	
	var refs = BLB.get_references(player_id, game_server)
	if refs.is_empty():
		print("⚠️  No hay referencias para ", player_id)
		return
	
	# 1. Arena cleanup
	if refs.player and refs.player.arena_reference:
		ArenaPveEngine.handle_player_disconnect_in_arena(player_id)
	
	# 2. Map cleanup (esto incluye borrar nodo player)
	if refs.map:
		WorldMapEngine.remove_player_from_map(player_id, refs.map)
	
	# 3. Container cleanup
	var container = BLB.get_player_container(player_id, game_server)
	if container:
		container.queue_free()
#endregion

#region TELEPORT TO OTHER MAP

static func change_map(player_id: int, target_map: String, spawn_position: Vector2, game_server: Node) -> void:
	print("🔄 CHANGE_MAP: ", player_id, " → ", target_map)
	
	var pc = BLB.get_player_container(player_id, game_server)
	if not pc:
		print("❌ CHANGE_MAP: No container")
		return
	
	var current_map = pc.stats["M"]
	
	# 1. Remover del mapa actual (si existe)
	if current_map != target_map:
		var current_map_node = BLB.get_map_node(current_map, game_server)
		if current_map_node:
			WorldMapEngine.remove_player_from_map(player_id, current_map_node)
	
	# 2. Actualizar stats
	pc.stats["M"] = target_map
	pc.stats["Px"] = spawn_position.x
	pc.stats["Py"] = spawn_position.y
	
	# 3. Agregar al mapa destino
	var target_map_node = BLB.get_map_node(target_map, game_server)
	if target_map_node:
		WorldMapEngine.add_player_to_map(player_id, pc, target_map_node)
	
	# 4. Notificar al cliente
	var data = {
		"mapa_destino": target_map,
		"stats": pc.stats.duplicate()
	}
	
	game_server.ServerSendToOneClient(player_id, "ChangeMap", data)
	print("✅ CHANGE_MAP completado: ", player_id)
#endregion

#region  RESPAWN AFTER DEAD
static func handle_player_respawn(player_id: int, gs: Node, refs: Dictionary) -> bool:
	print("🔄 [RESPAWN] Iniciando para jugador ", player_id)
	
	var container = refs.container
	var stats = container.stats
	var digimons = container.digimon_memory
	var old_map = stats["M"]
	var respawn_map = "Mapa1"
	var respawn_position = Vector2(500, 300)
	
	# 1. Remover del mapa actual (SIEMPRE, aunque sea el mismo mapa)
	# Porque el nodo actual tiene estado DEAD
	var current_map_node = BLB.get_map_node(old_map, gs)
	if current_map_node:
		WorldMapEngine.remove_player_from_map(player_id, current_map_node)
	
	# 2. Actualizar stats del container
	stats["M"] = respawn_map
	stats["Px"] = respawn_position.x
	stats["Py"] = respawn_position.y
	stats["Health"] = 1  # 50% de vida
	
	# 3. Agregar al mapa de respawn (crea NUEVO nodo con estado fresco)
	var respawn_map_node = BLB.get_map_node(respawn_map, gs)
	if respawn_map_node:
		WorldMapEngine.add_player_to_map(player_id, container, respawn_map_node)
	else:
		print("❌ [RESPAWN] Mapa de respawn no encontrado: ", respawn_map)
		return false

	
	# 6. Notificar al cliente
	var respawn_data = {
		"respawn": true,
		"mapa": respawn_map,
		"position": {"x": respawn_position.x, "y": respawn_position.y},
		"stats": stats.duplicate(),
		"digimons": digimons
	}
	gs.ServerSendToOneClient(player_id, "PlayerRespawned", respawn_data)
	
	print("✅ [RESPAWN] Jugador ", player_id, " respawneado en ", respawn_map)
	return true
#endregion
