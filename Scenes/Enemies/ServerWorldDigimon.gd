extends CharacterBody2D

#region VARIABLES Y CONFIGURACIÓN
signal enemy_died(enemy_id)

enum State { IDLE, WANDER, CHASE, ARENA, ATTACK, DEAD, RETURN }
var current_state = State.IDLE

var nickname := ""
var dict_state = {}
var dict_data = {}
var spawn_position: Vector2 = Vector2.ZERO
var map_reference = null
var target_node: Node = null
var state_timer: float = 2.0
var path_update_timer: float = 0.0
var regen_accumulator: float = 0.0
var is_in_combat := false
var enemy_id := ""
var enemy_map := ""
var animation_vector = Vector2.ZERO

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
#endregion

#region PUBLIC METHODS
func setup_enemy(net_state: Dictionary, db_data: Dictionary):
	dict_state = net_state
	dict_data = db_data
	spawn_position = global_position
	nickname = net_state["N"]
#endregion

#region CORE PROCESS
func _physics_process(delta):
	WorldDigimonEngine.update_all_systems(self, delta)
#endregion
