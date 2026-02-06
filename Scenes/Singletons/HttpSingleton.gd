extends Node

#region URLS
var character_db_url := "http://127.0.0.1:1912/api/gameserver/character-db"
var world_enemys_url := "http://127.0.0.1:1912/api/gameserver/world-enemys"
var finish_arena_url := "http://127.0.0.1:1912/api/gameserver/finish-arena"
#endregion

#region API METHODS
func GetCharacterByName(name_value):
	var res = await BLB._api_request(character_db_url, HTTPClient.METHOD_POST, { "name": str(name_value) })
	return res.get("data", null) if res else null

func GetWorldEnemys():
	var res = await BLB._api_request(world_enemys_url, HTTPClient.METHOD_GET)
	return res.get("data", null) if res else null



func SaveArenaResults(player_id: String, stats: Dictionary, digimons: Array):
	var payload = {
		"player_id": player_id,
		"stats": stats,
		"digimons": digimons
	}
	# Usamos await para asegurar que se procese, aunque sea MVP
	var res = await BLB._api_request(finish_arena_url, HTTPClient.METHOD_POST, payload)
	return res != null
	
	
	
#endregion
