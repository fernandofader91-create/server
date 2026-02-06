class_name PlayerMoveRequest

#region REQUEST HANDLER
func handle_request(player_id: int, request_data, game_server: Node) -> bool:
	return PlayerEngine.handle_client_mouse_request(player_id, request_data, game_server)
#endregion
