extends Node
class_name ArenaPveEngine

static var active_arenas = {}

#region START ARENA
static func start_arena_pve(enemy: Node, player: Node) -> bool:
	if not is_instance_valid(enemy) or not is_instance_valid(player):
		return false
	if BLB.is_entity_in_arena(enemy) or BLB.is_entity_in_arena(player):
		return false

	enemy.current_state = enemy.State.ARENA
	player.current_state = player.State.ARENA
	enemy.set_physics_process(false)
	player.set_physics_process(false)
	enemy.velocity = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.remove_from_group("Jugador")
	enemy.target_node = null

	_sync_arena_state_to_client(player)

	var gs = BLB.get_gameserver()
	var player_id = int(str(player.name))
	var player_container = BLB.get_player_container(player_id, gs)
	if not player_container:
		return false

	var map_name = player_container.stats.get("M", "")
	var map_node = BLB.get_map_node(map_name, gs)
	if not map_node:
		return false

	var arena_id = "arena_%s_vs_%s" % [str(enemy.name), str(player.name)]

	var arena_scene = preload("res://Scenes/Maps/ArenaPVE.tscn")
	var arena_instance = arena_scene.instantiate()
	var container_arenas = gs.get_node("ContainerArenas")
	container_arenas.add_child(arena_instance)
	player.arena_reference = arena_instance
	
	var container_offset = container_arenas.global_position
	var arena_local_offset = arena_instance.position
	var offset_total = container_offset + arena_local_offset
	
	var spawn_left = Vector2(250, 300)
	var spawn_right = Vector2(750, 300)
	
	randomize()
	var player_side = randi() % 2
	var enemy_side = 1 - player_side
	
	var player_spawn_pos = spawn_left if player_side == 0 else spawn_right
	var enemy_spawn_pos = spawn_left if enemy_side == 0 else spawn_right

	arena_instance.setup_arena_pve(
		arena_id,
		str(player.name),
		str(enemy.name),
		player_spawn_pos,
		enemy_spawn_pos,
		player_container,
		{
			"stats": enemy.dict_data["stats"],
			"zone_name": enemy.dict_data.get("zone_name", ""),
			"state": enemy.dict_state
		},
		map_node
	)

	active_arenas[arena_id] = {
		"arena_instance": arena_instance,
		"enemy": enemy,
		"player": player,
		"enemy_id": str(enemy.name),
		"player_id": str(player.name),
		"start_time": Time.get_ticks_msec(),
		"player_spawn_side": "left" if player_side == 0 else "right",
		"arena_offset": offset_total
	}
		
	if gs and gs.has_method("ServerSendToOneClient"):
		var arena_info = {
			"arena_id": arena_id,
			"arena_offset": offset_total,
			"player_spawn": player_spawn_pos,
			"enemy_spawn": enemy_spawn_pos,
			"player_id": str(player.name),
			"enemy_id": str(enemy.name),
			"player_side": "left" if player_side == 0 else "right",
			"enemy_side": "left" if enemy_side == 0 else "right"
		}
		gs.ServerSendToOneClient(player_id, "ArenaPVECreated", arena_info)

	_create_arena_timeout(arena_id)
	return true
#endregion

#region END ARENA
static func end_arena_pve(arena_id: String, winner: String, disconnected_player: bool = false) -> void:
	if not active_arenas.has(arena_id):
		return
	
	var arena_data = active_arenas[arena_id]
	var world_enemy = arena_data.get("enemy")
	var player = arena_data.get("player")
	var arena_instance = arena_data.get("arena_instance")
	
	# 1. OBTENER LOS DIGIMONS DE LA ARENA
	var arena_enemy = null
	var player_digimon_arena = null
	
	if is_instance_valid(arena_instance):
		var enemy_id = arena_data.get("enemy_id", "")
		var player_id_str = str(player.name)
		
		if enemy_id != "":
			arena_enemy = arena_instance.get_node_or_null("Node/Digimons/" + enemy_id)
		
		player_digimon_arena = arena_instance.get_node_or_null("Node/Digimons/" + player_id_str)
		
		if not arena_enemy:
			var digimons_node = arena_instance.get_node_or_null("Node/Digimons")
			if digimons_node:
				for child in digimons_node.get_children():
					if child.name != player_id_str:
						arena_enemy = child
					else:
						player_digimon_arena = child
	
	# 2. SINCRONIZAR HP DEL ENEMIGO DE ARENA → MUNDO
	if is_instance_valid(world_enemy):
		world_enemy.set_physics_process(true)
		world_enemy.velocity = Vector2.ZERO
		
		if is_instance_valid(arena_enemy):
			var arena_hp = arena_enemy.enemy_state.get("Health", 0)
			var max_hp = arena_enemy.enemy_state.get("MHealth", 100)
			world_enemy.dict_state["HP"] = arena_hp
			world_enemy.dict_state["MHP"] = max_hp
			print("    🩹 Sincronizando HP enemigo: ", arena_hp, "/", max_hp)
		
		if winner == "player":
			world_enemy.current_state = world_enemy.State.DEAD
			print("    ☠️ Enemigo derrotado")
		elif winner == "enemy":
			world_enemy.current_state = world_enemy.State.RETURN
			world_enemy.target_node = null
		else:
			world_enemy.current_state = world_enemy.State.RETURN
			world_enemy.target_node = null
	
	# 3. RESTAURAR PLAYER
	if is_instance_valid(player):
		player.set_physics_process(true)
		player.velocity = Vector2.ZERO
		if not player.is_in_group("Jugador"):
			player.add_to_group("Jugador")
		player.current_state = player.State.IDLE
	
	# 4. ENVIAR DATOS AL CLIENTE Y DAR RECOMPENSAS
	if is_instance_valid(player) and not disconnected_player:
		var gs = BLB.get_gameserver()
		var player_id = int(str(player.name))
		
		if gs and gs.has_method("ServerSendToOneClient") and player_id > 0:
			var player_container = BLB.get_player_container(player_id, gs)
			
			if player_container and is_instance_valid(player_digimon_arena) and player_digimon_arena.has("enemy_state"):
				var digimon_hp = player_digimon_arena.enemy_state.get("Health", 0)
				var digimon_max_hp = player_digimon_arena.enemy_state.get("MHealth", 50)
				
				if player_container.digimon_memory and player_container.digimon_memory.size() > 0:
					var digimon = player_container.digimon_memory[0]
					digimon["stats"]["hp"] = digimon_hp
					digimon["stats"]["Mhp"] = digimon_max_hp
					print("    💚 HP digimon sincronizado: ", digimon_hp, "/", digimon_max_hp)
			
			if player_container and winner == "player":
				print("    🎁 Dando recompensas por victoria")
				var player_xp = 50
				player_container.stats["Exp"] = player_container.stats.get("Exp", 0) + player_xp
				var player_exp_needed = player_container.stats.get("ExpR", 100)
				while player_container.stats["Exp"] >= player_exp_needed:
					player_container.stats["Exp"] -= player_exp_needed
					player_container.stats["Level"] = player_container.stats.get("Level", 1) + 1
				
				if player_container.digimon_memory and player_container.digimon_memory.size() > 0:
					var current_digimon = player_container.digimon_memory[0]
					var digimon_xp = 90
					current_digimon["exp"] = current_digimon.get("exp", 0) + digimon_xp
					var digimon_exp_needed = 100
					while current_digimon["exp"] >= digimon_exp_needed:
						current_digimon["exp"] -= digimon_exp_needed
						current_digimon["level"] = current_digimon.get("level", 1) + 1
				
				var money = 10
				if player_container.stats.has("Money"):
					player_container.stats["Money"] += money
				else:
					player_container.stats["Money"] = money
			
			elif player_container and winner == "enemy":
				if player_container.digimon_memory and player_container.digimon_memory.size() > 0:
					var digimon = player_container.digimon_memory[0]
					digimon["stats"]["hp"] = 0
			
			
			var db_name = player_container.nombre
			# ✅ PERSISTENCIA API (NUEVO)
			if player_container:
				HttpSingleton.SaveArenaResults(db_name, player_container.stats, player_container.digimon_memory)

			var finish_info = {
				"arena_id": arena_id,
				"winner": winner,
				"map_offset": arena_data.get("arena_offset", Vector2.ZERO),
				"reason": "battle_end"
			}
			
			if player_container:
				finish_info["digimons_memory"] = player_container.digimon_memory.duplicate(true)
				finish_info["player_stats"] = player_container.stats.duplicate()
			
			gs.ServerSendToOneClient(player_id, "ArenaPVEFinish", finish_info)
	
	# 5. LIMPIAR ARENA
	if is_instance_valid(arena_instance):
		arena_instance.queue_free()
	
	if arena_data.has("timeout_timer") and is_instance_valid(arena_data["timeout_timer"]):
		arena_data["timeout_timer"].queue_free()
	
	active_arenas.erase(arena_id)
	print("    ✅ Arena terminada: ", arena_id, " - Ganador: ", winner)
#endregion


#region TIMEOUT
static func _create_arena_timeout(arena_id: String) -> void:
	var arena_node = BLB.get_arena_node(arena_id)
	
	if not arena_node:
		return
	
	var timer = Timer.new()
	timer.name = arena_id + "_timeout"
	timer.wait_time = 180
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(_on_arena_timeout.bind(arena_id))
	
	arena_node.add_child(timer)
	# Guardar referencia si el arena_id está en active_arenas
	if active_arenas.has(arena_id):
		active_arenas[arena_id]["timeout_timer"] = timer
		print(" Timer creado como hijo de arena: ", arena_id)

static func _on_arena_timeout(arena_id: String) -> void:
	if not active_arenas.has(arena_id):
		return
	
	print(" Timeout de arena: ", arena_id)
	
	var arena_data = active_arenas[arena_id]
	var enemy = arena_data.get("enemy")
	var player = arena_data.get("player")
	
	if not is_instance_valid(player):
		end_arena_pve(arena_id, "enemy")
	else:
		end_arena_pve(arena_id, "draw")
#endregion

#region PLAYER DISCONNECT
static func handle_player_disconnect_in_arena(player_id: int) -> void:
	var arena_to_end = null
	
	for arena_id in active_arenas:
		var arena_data = active_arenas[arena_id]
		
		if str(player_id) == arena_data["player_id"]:
			arena_to_end = arena_id
			break
	
	if arena_to_end:
		end_arena_pve(arena_to_end, "enemy")
		
		var arena_data = active_arenas.get(arena_to_end)
		if arena_data and arena_data.get("timeout_timer"):
			arena_data["timeout_timer"].queue_free()
#endregion




static func _sync_arena_state_to_client(player: Node) -> void:
	if not is_instance_valid(player):
		return
	
	var state = player.dict_state
	state["ST"] = "arena"
	
	# Enviar al cliente
	var gs = BLB.get_gameserver()
	var player_id = int(str(player.name))
	
	if gs and gs.has_method("ServerSendToOneClient"):
		gs.ServerSendToOneClient(player_id, "ForceStateSync", {"ST": "arena"})
	
	print("🔥 Estado ARENA forzado a cliente para: ", player.nickname)
