class_name TimeSyncRequest

#region REQUEST HANDLER
func handle_request(player_id: int, request_data, game_server: Node) -> bool:
	return PlayerLifecycleEngine.handle_time_sync(player_id, request_data, game_server)
#endregion
