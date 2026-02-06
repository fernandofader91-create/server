extends Area2D
class_name Teleport

@export var mapa_actual: String  # Para referencia en editor
@export var mapa_siguiente: String  # Para el cambio
@export var spawn_point: Vector2  # Posición de spawn en mapa destino

#region AREA EVENTS
func _on_body_entered(body: Node2D) -> void:
	var player_id = int(str(body.name))
	var gs = BLB.get_gameserver()
	
	PlayerLifecycleEngine.change_map(player_id, mapa_siguiente, spawn_point, gs)
#endregion
