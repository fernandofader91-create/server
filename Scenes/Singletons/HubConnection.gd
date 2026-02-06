extends Node

#region ENUMS & CONSTANTS
enum MessageTypes {
	SERVER_CONNECT = 1,      # El GameServer se registra en el hub
	CLIENT_CONNECT = 2,      # Un cliente solicita conexión al GameServer
	SERVER_CONNECT_RESULT = 3, # Confirmación del registro del GameServer
	USER_CONNECTED = 4,      # Conexión de un cliente al gameserver
}

const TOKEN = "gameserver1234"
#endregion

#region SIGNALS
signal packet_received(type: int, data: Dictionary)  # Emitida cuando llega un paquete válido
signal connection_server                              # Para notificar éxito de conexión al hub
signal connection_fail(reason: String)               # Emitida si falla la conexión inicial
#endregion

#region VARIABLES
var _socket: WebSocketPeer = WebSocketPeer.new()     # WebSocket para conectar al hub central
var _name_sent: bool = false                         # Flag para saber si ya enviamos el nombre del servidor
#endregion

#region INITIALIZATION
func _ready() -> void:
	connect_server("ws://127.0.0.1:1912")
	#connect_server("ws://217.196.61.125:1912")

func connect_server(ip: String) -> void:
	var err: int = _socket.connect_to_url(ip)
	if err == OK:
		print("Conectando a ", ip)
		set_process(true)
	else:
		push_error("Error al conectar: ", err)
		connection_fail.emit("Error al conectar")
#endregion

#region NETWORK COMMUNICATION
func send_packet(type: int, data: Dictionary) -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	
	var json: String = JSON.stringify({type = type, data = data})
	_socket.send_text(json)

func _process(_delta: float) -> void:
	_socket.poll()
	
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _name_sent:
				send_packet(MessageTypes.SERVER_CONNECT, {
					"name": "Latinoamerica",
					"token": TOKEN
				})
				_name_sent = true
			_process_packets()
		
		WebSocketPeer.STATE_CLOSED:
			print("Conexión cerrada")

func _process_packets() -> void:
	while _socket.get_available_packet_count() > 0:
		var raw: String = _socket.get_packet().get_string_from_utf8()
		var pkt: Variant = JSON.parse_string(raw)
		
		if typeof(pkt) != TYPE_DICTIONARY or not pkt.has("type") or not pkt.has("data"):
			continue
		
		_handle_packet(pkt as Dictionary)
#endregion

#region PACKET HANDLING
func _handle_packet(pkt: Dictionary) -> void:
	var type_str: String = pkt["type"]
	var data: Dictionary = pkt["data"]
	
	var type: int = {
		"SERVER_CONNECT": MessageTypes.SERVER_CONNECT,
		"CLIENT_CONNECT": MessageTypes.CLIENT_CONNECT,
		"SERVER_CONNECT_RESULT": MessageTypes.SERVER_CONNECT_RESULT,
		"USER_CONNECTED": MessageTypes.USER_CONNECTED,
	}.get(type_str, -1)
	
	if type == -1:
		return
	
	match type:
		MessageTypes.SERVER_CONNECT_RESULT:
			get_node("/root/GameServer").server_id = data.server_id
			# connection_server.emit() # Opcional
		
		MessageTypes.USER_CONNECTED:
			if data.has("token"):
				var token = data["token"]
				var server_id = get_node("/root/GameServer").server_id
				get_node("/root/GameServer").expected_tokens.append(token)
			# Opcional: manejar otros casos
		
		_:
			packet_received.emit(type, data)
#endregion
