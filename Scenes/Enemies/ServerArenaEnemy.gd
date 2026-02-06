extends CharacterBody2D

#region VARIABLES
signal enemy_died(enemy_id)

enum State { IDLE, WANDER, CHASE, ARENA, ATTACK, DEAD, RETURN }
var current_state = State.IDLE

var enemy_type := "Agumon"
var enemy_state = {}
var enemy_data = {}
var spawn_position: Vector2 = Vector2.ZERO
var map_reference = null
var world_map_reference = null

var chase_target: Node = null
var state_timer: float = 2.0
var chase_update_timer: float = 0.0
var regen_accumulator: float = 0.0

var is_in_combat := false
var enemy_id := ""
var enemy_map := ""
var animation_vector = Vector2.ZERO

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
#endregion

#region INIT
func _ready():
	if spawn_position == Vector2.ZERO:
		spawn_position = global_position
	
	await get_tree().physics_frame
	nav_agent.path_desired_distance = 10.0
	nav_agent.target_desired_distance = 16.0
	
	if not nav_agent.velocity_computed.is_connected(_on_navigation_agent_2d_velocity_computed):
		nav_agent.velocity_computed.connect(_on_navigation_agent_2d_velocity_computed)
	
	print("[ARENA ENEMY] Inicializado: ", name)

func setup_digimon(enemy_data_dict: Dictionary):
	enemy_id = enemy_data_dict["id"]
	enemy_type = "Agumon"
	map_reference = enemy_data_dict["arena_reference"]
	
	if enemy_data_dict.has("stats"):
		var stats_copy = enemy_data_dict["stats"].duplicate(true)
		stats_copy["M"] = str(map_reference.name)
		enemy_state = stats_copy
	else:
		enemy_state = {}
	
	enemy_data = enemy_data_dict
	name = "Enemy_" + str(enemy_data_dict["id"])
	position = enemy_data_dict["spawn"]
	
	if spawn_position == Vector2.ZERO:
		spawn_position = position
	
	print("[ARENA ENEMY] Configurado: ", name, " | HP: ", enemy_state.get("Health", 0))
#endregion

#region MOTOR FÍSICA
func _physics_process(delta):
	ArenaEnemyEngine.update_all_systems(self, delta)

func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2):
	velocity = safe_velocity
	move_and_slide()
#endregion

#region COMANDOS
func TakeDamage(player_id: String, skill_damage: int):
	ArenaEnemyEngine.take_damage(self, player_id, skill_damage)

func ReceiveDamage(enemy_id: String, damage: int):
	print("🎯 ENEMIGO RECIBE | Nombre:", name, " | De:", enemy_id, " | Daño:", damage)
	print("   Vida ANTES:", enemy_state.get("Health", "NO-EXISTE"))
	TakeDamage(enemy_id, damage)
#endregion

#region MÉTODOS DE AYUDA
func get_enemy_id() -> String:
	return enemy_id

func get_enemy_state() -> Dictionary:
	return enemy_state

func get_map_reference() -> Node:
	return map_reference

func is_dead() -> bool:
	return current_state == State.DEAD
#endregion
