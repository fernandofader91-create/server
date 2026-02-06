extends Node

var game_server: ENetMultiplayerPeer
const SERVER_PORT: int = 1911
const MAX_PLAYERS: int = 100
var expected_tokens: Array = []
var awaiting_verification: Dictionary = {}
var server_id
var request_handlers = {}

#SCRIPT OPMTIZADO 100 %

#region INITIALIZATION
func _ready():
	await ServerData.initialize_data()
	start_game_server(SERVER_PORT, MAX_PLAYERS)
	_register_request_handlers()

func start_game_server(port: int, max_players: int) -> void:
	game_server = ENetMultiplayerPeer.new()
	var result = game_server.create_server(port, max_players)
	if result != OK:
		push_error("[SERVER] Failed to start GameServer: %d" % result)
		return
	multiplayer.multiplayer_peer = game_server
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
#endregion

#region REQUEST HANDLERS
func _register_request_handlers():
	request_handlers["FetchServerTime"] = TimeSyncRequest.new()
	request_handlers["FetchToken"] = FetchTokenRequest.new()
	request_handlers["DetermineLatency"] = DetermineLatencyRequest.new()
	request_handlers["LoadCharacter"] = LoadCharacterRequest.new()
	request_handlers["PlayerMove"] = PlayerMoveRequest.new() #player mundo
	request_handlers["DigimonMove"] = DigimonMoveRequest.new() #player digimon arena
#endregion

#region NETWORK EVENTS
func _on_peer_connected(player_id: int) -> void:
	print_rich("[CLIENT] 🟢 Jugador conectado: %d" % player_id)
	var peer = game_server.get_peer(player_id)
	peer.set_timeout(2500, 2500, 2500)
	PlayerLifecycleEngine.auth_start(player_id)

func _on_peer_disconnected(player_id: int) -> void:
	PlayerLifecycleEngine.disconnect_client_instance(player_id, self)
#endregion

#region RPC METHODS
@rpc("any_peer", "call_remote", "reliable")
func ClientSendDataToServer(key, value):
	var player_id = multiplayer.get_remote_sender_id()
	if request_handlers.has(key):
		var handler = request_handlers[key]
		var success = await handler.handle_request(player_id, value, self)
		if not success:
			print_rich("[ERROR] Failed to process: %s" % key)
	else:
		print_rich("[ERROR] No handler for message: %s" % key)

@rpc("authority", "call_remote", "reliable")
func ServerSendToOneClient(player_id: int, key: String, data):
	rpc_id(player_id, "ServerSendToOneClient", key, data)

@rpc("authority", "call_remote", "reliable")
func ServerSendToAllClients(key: String, data):
	rpc("ServerSendToAllClients", key, data)

@rpc("authority", "call_remote", "reliable")
func ServerSendWorldState(world_state):
	rpc("ServerSendWorldState", world_state)
#endregion
