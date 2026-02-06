extends Node

#region VARIABLES
var world_enemies_data = []
# Futuro: var digimon_data = [], var skills_data = {}, var items_data = {}
#endregion

#region INICIALIZACIÓN
func initialize_data():
	print_rich("[SERVER_DATA]  Iniciando carga masiva de datos...")
	await load_enemies()
	# Futuro: await load_digimon(), await load_skills(), etc.
	print_rich("[SERVER_DATA]  Bootstrap de datos completado.")

func load_enemies():
	var result = await HttpSingleton.GetWorldEnemys()
	if result is Array:
		world_enemies_data = result
		print_rich("[SERVER_DATA]  Enemigos mundiales cargados: %d" % world_enemies_data.size())
#endregion
