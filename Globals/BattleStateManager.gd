extends Node

var battle_state: Dictionary

var current_player_id: String = "1089945453098971297"

var set_registry: Dictionary = {}

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

	#- Load BS.json set data
	var bs_file = FileAccess.open("res://Data/BS.json", FileAccess.READ)
	var bs_json_string = bs_file.get_as_text()
	bs_file.close()

	var bs_json = JSON.new()
	var bs_error = bs_json.parse(bs_json_string)
	if bs_error == OK:
		var bs_array = bs_json.get_data()
		var bs_dict = {}
		# Convert array of [key, value] pairs to dictionary
		for entry in bs_array:
			var card_id = entry[0]
			var card_data = entry[1]
			bs_dict[card_id] = card_data
		set_registry["BS"] = bs_dict
		print("BS set loaded: ", bs_dict.size(), " cards")
	else:
		print("BS.json parse error")


	SignalManager.attack_clicked.connect(handle_attack_clicked)
	pass



func get_active_pokemon():
	for card in battle_state.cards:
		if card.owner == current_player_id and card.location.type == "active":
			return card
	return null


func handle_attack_clicked(move_data):
	print("ATTACK SIGNAL RECEIVED", move_data)
