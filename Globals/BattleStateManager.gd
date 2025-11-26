extends Node

var battle_state: Dictionary

var current_player_id: String = "1089945453098971297"




func _ready():
	#- Load the JSON file from disk
	var file = FileAccess.open("res://Data/TestBattleState.json", FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
  #- Parse it into a Dictionary
	var json = JSON.new()
	var error = json.parse(json_string)
	if error == OK:
		battle_state = json.get_data().state
		print("LOADED")
		SignalManager.battle_state_loaded.emit(battle_state)
	else:
		print("JSON parse error")

  #- Emit the signal


	pass
