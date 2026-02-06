extends Node
class_name BLB

#SCRIPT OPTMIZADO CREO QUE 100%


#region NODOS PRINCIPALES
static func get_gameserver() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameServer")

static func get_map_node(map_name: String, game_server: Node) -> Node:
	return game_server.get_node_or_null("ContainerMaps/" + map_name)
#endregion

#region ESTADOS DE ENTIDADES
static func is_entity_dead(entity: Node) -> bool:    
	return entity.current_state == entity.State.DEAD

static func is_entity_in_arena(entity: Node) -> bool:
	return entity.current_state == entity.State.ARENA
#endregion

#region REFERENCIAS DE JUGADORES
static func get_references(player_id: int, game_server: Node) -> Dictionary:
	var container = get_player_container(player_id, game_server)
	if not container: 
		return {}
	
	var map_name = container.stats.get("M", "")
	var refs = {
		"container": container,
		"player": get_player_node(player_id, game_server, map_name),
		"map": get_map_node(map_name, game_server),
		"game_server": game_server
	}
	return refs

static func get_player_container(player_id: int, game_server: Node) -> Node:
	return game_server.get_node_or_null("ContainerPlayers/" + str(player_id))

static func get_player_node(player_id: int, game_server: Node, map_name: String) -> Node:
	return game_server.get_node_or_null("ContainerMaps/" + map_name + "/Node/Players/" + str(player_id))
#endregion

#region PLAYERS EN UN MAPA
static func get_players_in_map(map_name: String, game_server: Node = null) -> Array:
	"""Obtiene todos los jugadores en un mapa específico"""
	if not game_server:
		game_server = get_gameserver()
		if not game_server:
			return []
	
	var map_node = get_map_node(map_name, game_server)
	if not map_node:
		return []
	
	var players_node = map_node.get_node_or_null("Node/Players")
	return [] if not players_node else players_node.get_children()
#endregion

#region ARENAS
static func get_arena_node(arena_id: String, game_server: Node = null) -> Node:
	"""Obtiene una arena específica por su ID"""
	if not game_server:
		game_server = get_gameserver()
		if not game_server:
			return null
	return game_server.get_node_or_null("ContainerArenas/" + arena_id)

static func get_all_arenas(game_server: Node = null) -> Array:
	"""Obtiene todas las arenas activas"""
	if not game_server:
		game_server = get_gameserver()
		if not game_server:
			return []
	
	var container_arenas = game_server.get_node_or_null("ContainerArenas")
	return [] if not container_arenas else container_arenas.get_children()

static func get_players_in_arena(arena_id: String, game_server: Node = null) -> Array:
	"""Obtiene todos los jugadores/digimons en una arena específica"""
	var arena_node = get_arena_node(arena_id, game_server)
	if not arena_node:
		return []
	
	var players_node = arena_node.get_node_or_null("Node/Players")
	return [] if not players_node else players_node.get_children()
#endregion

#region HTTP
static func _api_request(url: String, method: int, payload: Dictionary = {}) -> Variant:
	var gs = get_gameserver()
	var http := HTTPRequest.new()
	gs.add_child(http)

	var headers = PackedStringArray([
		"Content-Type: application/json",
		"X-GS-Token: %s" % HubConnection.TOKEN
	])
	
	var json_data = JSON.stringify(payload) if not payload.is_empty() else ""
	var err = http.request(url, headers, method, json_data)
	
	if err != OK:
		http.queue_free()
		return null

	var res = await http.request_completed
	http.queue_free()

	var code = res[1]
	var body = res[3].get_string_from_utf8()
	var parsed = JSON.parse_string(body)

	if code == 200 and typeof(parsed) == TYPE_DICTIONARY and parsed.get("success", false):
		return parsed
	
	print("[BLB] [HTTP_ERROR] URL: %s | Code: %d | Body: %s" % [url, code, body])
	return null
#endregion
