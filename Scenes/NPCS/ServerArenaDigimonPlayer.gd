extends CharacterBody2D
class_name ServerArenaDigimonPlayer

#region VARIABLES
enum State { IDLE, MOVE, ATTACK, DEAD }
var current_state = State.IDLE

var spawn_position: Vector2
var player_container: Node
var digimon_state: Dictionary
var digimon_data: Dictionary
var map_reference: Node
var world_map_reference: Node
var digimon_index: int

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
var animation_vector := Vector2.DOWN
var target_pos: Vector2
var attack_timer: float = 0.0
#endregion

#region INIT
func _ready():
	await get_tree().physics_frame
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 1.0
	
	if not nav_agent.velocity_computed.is_connected(_on_navigation_agent_2d_velocity_computed):
		nav_agent.velocity_computed.connect(_on_navigation_agent_2d_velocity_computed)

func setup_digimon(data: Dictionary):
	name = data["id"]
	position = data["spawn_position"]
	spawn_position = data["spawn_position"]
	player_container = data["playerC_reference"]
	digimon_data = data["data"]
	digimon_state = digimon_data["stats"]
	map_reference = data["arena_reference"]
#endregion

#region MOTOR FÍSICA
func _physics_process(delta):
	ArenaDigimonEngine.update_all_systems(self, delta)

func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2):
	ArenaDigimonEngine._apply_movement(self, safe_velocity)
#endregion

#region COMANDOS
func RequestMovement(t_pos: Vector2):
	ArenaDigimonEngine.request_movement(self, t_pos)

func ReceiveDamage(enemy_id: String, damage: int):
	ArenaDigimonEngine.receive_damage(self, enemy_id, damage, str(map_reference.name))
#endregion
