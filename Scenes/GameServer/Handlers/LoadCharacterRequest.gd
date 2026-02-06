class_name LoadCharacterRequest

#region REQUEST HANDLER
func handle_request(player_id: int, request_data, game_server: Node) -> bool:
	return await PlayerLifecycleEngine.handle_load_character(
		player_id, 
		request_data, 
		game_server
	)
#endregion
