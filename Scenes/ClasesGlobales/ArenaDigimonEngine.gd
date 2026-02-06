extends Node
class_name ArenaDigimonEngine

#region UPDATE SYSTEMS
static func update_all_systems(digimon: Node, delta: float) -> void:
	if not is_instance_valid(digimon):
		return
	
	update_state_system(digimon, delta)
	_update_sync_to_arena(digimon)

#region STATE SYSTEM
static func update_state_system(digimon: Node, delta: float) -> void:
	match digimon.current_state:
		digimon.State.IDLE:
			_process_idle_state(digimon, delta)
		digimon.State.MOVE:
			_process_move_state(digimon, delta)
		digimon.State.ATTACK:
			_process_attack_state(digimon, delta)
		digimon.State.DEAD:
			_process_dead_state(digimon, delta)

static func _process_idle_state(digimon: Node, delta: float) -> void:
	digimon.velocity = digimon.velocity.lerp(Vector2.ZERO, 0.2)
	digimon.move_and_slide()
	
	# Verificar si hay enemigo cerca para atacar
	var enemy = _find_enemy_in_range(digimon, 16.0)
	if enemy:
		set_digimon_attack(digimon)

static func _process_move_state(digimon: Node, delta: float) -> void:
	if digimon.nav_agent.is_navigation_finished():
		set_digimon_idle(digimon)
		return

	var next_path_pos = digimon.nav_agent.get_next_path_position()
	var dir = digimon.global_position.direction_to(next_path_pos)
	digimon.animation_vector = dir
	
	var speed = digimon.digimon_state["spd"]
	var intended_velocity = dir * speed
	
	if digimon.nav_agent.avoidance_enabled:
		digimon.nav_agent.set_velocity(intended_velocity)
	else:
		_apply_movement(digimon, intended_velocity)
	
	digimon.move_and_slide()
	
	# Verificar si llegó a un enemigo mientras se mueve
	var enemy = _find_enemy_in_range(digimon, 16.0)
	if enemy:
		set_digimon_attack(digimon)

static func _process_attack_state(digimon: Node, delta: float) -> void:
	if not digimon.player_container:
		set_digimon_idle(digimon)
		return
	
	var hp = digimon.player_container.digimon_memory[0]["stats"]["hp"]
	if hp <= 0:
		set_digimon_dead(digimon)
		return
	
	# Buscar enemigo en rango
	var enemy = _find_enemy_in_range(digimon, 16.0)
	if not enemy:
		set_digimon_idle(digimon)
		return
	print("🤺 ATACANDO | Digimon:", digimon.name, " | Enemigo:", enemy.name)
	print("   Distancia:", digimon.global_position.distance_to(enemy.global_position))
	print("   ¿Tiene ReceiveDamage?:", enemy.has_method("ReceiveDamage"))
	# Timer de ataque
	digimon.attack_timer -= delta
	if digimon.attack_timer <= 0:
		var damage = digimon.digimon_state.get("atk", 10)
		
		if enemy.has_method("ReceiveDamage"):
			enemy.ReceiveDamage(digimon.name, damage)
		
		var aspeed = digimon.digimon_state.get("ASpeed", 100)
		digimon.attack_timer = max(0.5, 2.0 / (aspeed / 100.0))
	
	# Frenar movimiento mientras ataca
	digimon.velocity = digimon.velocity.lerp(Vector2.ZERO, 0.5)
	digimon.move_and_slide()

static func _process_dead_state(digimon: Node, delta: float) -> void:
	digimon.velocity = Vector2.ZERO
#endregion

#region STATE SETTERS
static func set_digimon_idle(digimon: Node) -> void:
	if digimon.current_state == digimon.State.IDLE:
		return
	if digimon.current_state != digimon.State.DEAD:
		digimon.current_state = digimon.State.IDLE
		digimon.velocity = Vector2.ZERO

static func set_digimon_move(digimon: Node) -> void:
	if digimon.current_state == digimon.State.MOVE:
		return
	if digimon.current_state != digimon.State.DEAD:
		digimon.current_state = digimon.State.MOVE

static func set_digimon_attack(digimon: Node) -> void:
	if digimon.current_state == digimon.State.ATTACK:
		return
	if digimon.current_state != digimon.State.DEAD:
		digimon.current_state = digimon.State.ATTACK
		digimon.attack_timer = 0.0  # Iniciar ataque inmediato

static func set_digimon_dead(digimon: Node) -> void:
	digimon.current_state = digimon.State.DEAD
	digimon.velocity = Vector2.ZERO
#endregion

#region MOVEMENT SYSTEM
static func _apply_movement(digimon: Node, safe_velocity: Vector2):
	digimon.velocity = safe_velocity

static func _find_enemy_in_range(digimon: Node, range: float) -> Node:
	if digimon.map_reference:
		var enemies_node = digimon.map_reference.get_node("Node/Digimons")
		if enemies_node:
			for enemy in enemies_node.get_children():
				if enemy != digimon and is_instance_valid(enemy):
					if enemy.name.begins_with("Enemy_"):
						var dist = digimon.global_position.distance_to(enemy.global_position)
						if dist <= range:
							return enemy
	return null
#endregion

#region SYNC SYSTEM
static func _update_sync_to_arena(digimon: Node) -> void:
	if not digimon.map_reference:
		return
	
	if not digimon.player_container:
		return
	
	var state = {
		"T": Time.get_ticks_msec(),
		"Px": digimon.global_position.x,
		"Py": digimon.global_position.y,
		"h": digimon.player_container.digimon_memory[0]["stats"]["hp"],
		"mh": 50,
		"spd": digimon.digimon_state["spd"],
		"A": digimon.animation_vector,
		"l": digimon.digimon_data["level"],
		"ST": digimon.State.keys()[digimon.current_state].to_lower()  # <-- ESTADO
	}
	
	digimon.map_reference.updatePlayerDigimonState(str(digimon.name), state)
#endregion

#region COMBAT SYSTEM
static func receive_damage(digimon: Node, enemy_id: String, damage: int, arena: String) -> void:
	if not digimon.player_container:
		return
	
	digimon.player_container.digimon_memory[0]["stats"]["hp"] -= damage
	
	if digimon.player_container.digimon_memory[0]["stats"]["hp"] <= 0:
		digimon.player_container.digimon_memory[0]["stats"]["hp"] = 0
		set_digimon_dead(digimon)
		ArenaPveEngine.end_arena_pve(arena, "enemy")
		return
#endregion

#region MOVEMENT COMMANDS
static func request_movement(digimon: Node, target_pos: Vector2) -> void:
	digimon.nav_agent.target_position = target_pos
	set_digimon_move(digimon)

static func handle_move_command(digimon: Node, target_pos: Vector2) -> bool:
	if not is_instance_valid(digimon):
		return false
	
	if digimon.player_container:
		var hp = digimon.player_container.digimon_memory[0]["stats"]["hp"]
		if hp <= 0:
			return false
	
	request_movement(digimon, target_pos)
	return true
#endregion
