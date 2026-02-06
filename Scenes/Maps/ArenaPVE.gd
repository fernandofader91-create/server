extends Control
class_name ArenaPVE

#region VARIABLES
var arena_id: String
var player_id: String
var enemy_id: String

var player_node
var enemy_node

var player_container: Node
var enemy_data: Dictionary

var player_states = {} 
var enemy_states = {}

var digimon_spawn = preload("res://Scenes/NPCS/ServerArenaDigimonPlayer.tscn")
var enemy_spawn = preload("res://Scenes/Enemies/ServerArenaEnemy.tscn")

var map_reference: Node
#endregion

#region INIT
func _ready():
	set_physics_process(false)
	print("[ARENA] Arena creada: ", name)
#endregion

#region SETUP ARENA
func setup_arena_pve(id: String, p_id: String, e_id: String, 
					p_position: Vector2, e_position: Vector2,
					player_container_ref: Node, enemy_world_data: Dictionary, map_ref: Node) -> void:
	
	arena_id = id
	player_id = p_id
	enemy_id = e_id
	name = id
	
	map_reference = map_ref
	player_container = player_container_ref
	enemy_data = enemy_world_data
	
	SpawnDigimon(player_container, p_position)
	SpawnEnemy(enemy_id, e_position, enemy_world_data)
	
	await get_tree().create_timer(0.1).timeout
	set_physics_process(true)
#endregion

#region SPAWNING
func SpawnDigimon(container: Node, spawn_position: Vector2) -> void:
	var new_digimon = digimon_spawn.instantiate()
	new_digimon.name = "Digimon_" + str(container.name)
	new_digimon.world_map_reference = map_reference
	
	var digimon_base_data = container.get_first_digimon()
	var digimon_data = {
		"data": digimon_base_data,
		"spawn_position": spawn_position,
		"arena_reference": self,
		"id": str(new_digimon.name),
		"playerC_reference": container,
	}
	
	new_digimon.setup_digimon(digimon_data)
	player_node = new_digimon
	
	get_node("Node/Players").call_deferred("add_child", new_digimon)
	
	await get_tree().process_frame
	new_digimon.position = spawn_position
	
	print("✅ [ARENA] Digimon del jugador spawneado en (local): ", new_digimon.position)

func SpawnEnemy(enemy_id: String, spawn_position: Vector2, enemy_world_data: Dictionary) -> void:
	var new_enemy = enemy_spawn.instantiate()
	new_enemy.name = "Enemy_" + enemy_id
	new_enemy.world_map_reference = map_reference
	
	var enemy_data_to_use = {
		"stats": enemy_world_data["stats"] if enemy_world_data.has("stats") else ServerData.world_enemies_data[0],
		"id": enemy_id,
		"spawn": spawn_position,
		"arena_reference": self,
		"playerC_reference": null
	}
	
	new_enemy.setup_digimon(enemy_data_to_use)
	enemy_node = new_enemy
	
	get_node("Node/Digimons").call_deferred("add_child", new_enemy)
	
	await get_tree().process_frame
	new_enemy.position = spawn_position
	
	print("✅ [ARENA] Enemigo spawneado en (local): ", new_enemy.position)
#endregion

#region SYNC Y ACTUALIZACIONES
func updatePlayerDigimonState(player_digimon: String, value: Dictionary) -> void:
	player_states[player_digimon] = value

func updateDigimonStates(p_id: String, value: Dictionary) -> void:
	if player_states.has(p_id) and player_states[p_id]["T"] > value["T"]:
		return 
	
	player_states[p_id] = value
	
	var digimon_node_name = "Digimon_" + str(p_id)
	var digimon_node = $Node/Digimons.get_node_or_null(digimon_node_name)
	
	if digimon_node:
		var new_pos = Vector2(value["Px"], value["Py"])
		digimon_node.position = new_pos
		
		var container_path = "/root/GameServer/ContainerPlayers/" + str(p_id)
		var player_container_node = get_node_or_null(container_path)
		
		if player_container_node:
			var digi_stats = player_container_node.get_fighting_digimon()
			if not digi_stats.is_empty():
				player_states[p_id]["hp"] = digi_stats["stats"]["hp"]
				player_states[p_id]["max_hp"] = digi_stats["stats"]["maxHp"]

func updateEnemyAIState(enemy_id: String, value: Dictionary) -> void:
	enemy_states[enemy_id] = value

func _physics_process(_delta: float) -> void:
	broadcast_arena_state()

func broadcast_arena_state() -> void:
	if player_id == "":
		return
	
	var arena_state = {}
	arena_state.merge(player_states)
	arena_state.merge(enemy_states)
	
	var new_arena_state = {
		"T": Time.get_ticks_msec(),
		"arena_id": arena_id,
		"digimons": arena_state
	}
	
	var server_node = get_node("/root/GameServer")
	if server_node:
		server_node.ServerSendToOneClient(int(player_id), "ArenaUpdate", new_arena_state)
#endregion

#region MOVIMIENTO DESDE CLIENTE
func MovePlayer(digimon_name: String, click_position: Vector2) -> bool:
	var digimon_node = $Node/Digimons.get_node_or_null(digimon_name)
	
	if not digimon_node:
		return false
	
	if digimon_node.has_method("RequestMovement"):
		digimon_node.RequestMovement(click_position)
		return true
	else:
		return false
#endregion

#region COMBATE
func EnemyAttackPlayer(damage: int) -> void:
	var player_container_node = get_node_or_null("/root/GameServer/ContainerPlayers/" + str(player_id))
	var server_node = get_node_or_null("/root/GameServer")
	
	if not player_container_node or not server_node:
		return
	
	player_container_node.apply_digimon_damage(damage)
	
	var current_digimon_hp = player_container_node.get_fighting_digimon().get("stats", {}).get("hp", 1)
	
	if current_digimon_hp <= 0:
		end_arena_battle(enemy_id, player_id, 0)
		return

func SpawnAttack(s_position: Vector2, a_rotation: float, a_position: Vector2, 
				a_direction: Vector2, player_id: int, map: String, 
				attack_name: String, attack_type: String, damage_amount: int) -> void:
	match attack_type:
		"RangedSingleTarget":
			var skill_new_instance = enemy_spawn.instantiate()
			skill_new_instance.player_id = player_id
			skill_new_instance.map = map
			skill_new_instance.skill_name = attack_name
			skill_new_instance.projectile_speed = 100
			skill_new_instance.skill_damage = damage_amount
			skill_new_instance.position = s_position
			skill_new_instance.direction = a_direction
			add_child(skill_new_instance)
#endregion

#region FIN DE ARENA
func end_arena_battle(winner_id: String, loser_id: String, experience_gained: int) -> void:
	set_physics_process(false)
	
	var winner = "enemy" if winner_id == enemy_id else "player"
	
	if ArenaPveEngine.active_arenas.has(arena_id):
		ArenaPveEngine.end_arena_pve(arena_id, winner)
	
	var arena_data = {
		"arena_id": name,
		"winner_id": winner_id,
		"loser_id": loser_id,
		"experience_gained": experience_gained,
	}
	
	var server_node = get_node("/root/GameServer")
	if server_node:
		server_node.ServerSendToOneClient(int(player_id), "EndArena", arena_data)
	
	var player_container_node = get_node("/root/GameServer/ContainerPlayers/" + str(player_id))
	if player_container_node:
		player_container_node.clear_fighting_digimon()
	
	if map_reference and map_reference.has_method("ArenaPveEnd"):
		map_reference.ArenaPveEnd(enemy_id, player_id)
	
	CleanDigimon()
	CleanEnemy()
	
	await get_tree().create_timer(2).timeout
	call_deferred("queue_free")

func CleanDigimon() -> void:
	if player_node and is_instance_valid(player_node):
		player_node.queue_free()

func CleanEnemy() -> void:
	if enemy_node and is_instance_valid(enemy_node):
		enemy_node.queue_free()
#endregion
