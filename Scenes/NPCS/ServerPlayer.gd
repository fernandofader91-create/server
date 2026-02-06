extends CharacterBody2D

#region SIGNALS
signal player_died(id)
#endregion

#region ENUMS
enum State { IDLE, MOVE, DEAD, ARENA }
#endregion

#region EXPORTS
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
#endregion

#region PUBLIC VARIABLES
var current_state = State.IDLE
var map_reference = null
var arena_reference = null
var container_reference = null
var nickname := ""

var animation_vector := Vector2.DOWN
var dict_state = {}
var dict_data = {}
#endregion

#region PUBLIC METHODS
func setup_player(net_state: Dictionary, db_data: Dictionary):
	dict_state = net_state
	dict_data = db_data
	nickname = net_state["N"]
#endregion

#region PHYSICS PROCESS
func _physics_process(delta):
	PlayerEngine.update_all_systems(self, delta)
#endregion
