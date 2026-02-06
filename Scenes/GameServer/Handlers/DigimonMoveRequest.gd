class_name DigimonMoveRequest

func handle_request(player_id: int, request_data, game_server: Node) -> bool:
	if request_data.size() < 3:
		return false
	
	var target_position = request_data[0]
	var location_id = str(request_data[1])
	var digimon_name = str(request_data[2])
	
	var arena_node = BLB.get_arena_node(location_id, game_server)
	
	if not arena_node:
		return false
	
	var digimon_node = arena_node.get_node_or_null("Node/Players/" + digimon_name)
	
	ArenaDigimonEngine.handle_move_command(digimon_node, target_position)
	return true
