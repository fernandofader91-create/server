class_name FetchTokenRequest

#region REQUEST HANDLER
func handle_request(player_id: int, request_data, game_server: Node) -> bool:
	return PlayerLifecycleEngine.handle_token_verification(
		player_id, 
		request_data["token"], 
		game_server
	)
#endregion
