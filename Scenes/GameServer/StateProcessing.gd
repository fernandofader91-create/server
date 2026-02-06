extends Node

#region CONSTANTS
const SYNC_FREQUENCY = 3  # Sincronizar cada 3 frames de física
#endregion

#region VARIABLES
var sync_clock_counter = 0
#endregion

#region PHYSICS PROCESS
func _physics_process(delta: float) -> void:
	sync_clock_counter += 1
	
	if sync_clock_counter % SYNC_FREQUENCY == 0:
		var world_state = WorldMapEngine.generate_world_state(get_parent())
		get_parent().ServerSendWorldState(world_state)
		
		if sync_clock_counter >= 1000:
			sync_clock_counter = 0
#endregion
