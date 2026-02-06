extends Area2D

#region HEALING AREA LOGIC
func _on_body_entered(body: Node2D) -> void:
	# Validaciones iniciales
	if not is_instance_valid(body):
		return
	
	if not is_instance_valid(body.container_reference):
		return
	
	var player_container = body.container_reference
	
	# Restaurar salud del jugador al máximo
	player_container["stats"]["Health"] = player_container["stats"]["MHealth"]
	
	# Restaurar salud del digimon al máximo
	player_container.digimon_memory[0]["stats"]["hp"] = 50
#endregion
