class_name DetermineLatencyRequest

#region REQUEST HANDLER
func handle_request(player_id: int, request_data, game_server: Node) -> bool:
	return PlayerLifecycleEngine.handle_latency(
		player_id, 
		request_data, 
		game_server
	)
#endregion
