extends Control
class_name BaseMap

@export var map_id: String = "MapaBase"
@export var pvp_enabled: bool = true
@export var enemy_maximum: int = 1
@export var zone_configs: Dictionary = {"Zona1": {"types": ["Agumon"], "max_enemies": 2}}
@export var map_offset : Vector2 = Vector2.ZERO

var zones_data = {}
var enemy_states = {}  
var player_states = {} 
var enemy_list = {}
var enemy_id_counter = 0

#region INITIALIZATION
func _ready():
	WorldMapEngine.setup_map(self)
#endregion

#region STATE MANAGEMENT
func ReceivePlayerState(p_state, p_id):
	player_states[str(p_id)] = p_state

func ReceiveEnemyState(state_chunk, id):
	enemy_states[str(id)] = state_chunk
#endregion

#region PROCESS
func _process(_delta):
	WorldMapEngine.collect_map_data(enemy_states, player_states)
#endregion
