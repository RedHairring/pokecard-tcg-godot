extends Control

@export var option_frame: PackedScene
@onready var actions_container = $ActionsContainer
@onready var attack_button = $ActionsContainer/AttackButton
@onready var close_click_layer: ColorRect = $CloseClickLayer

func _ready() -> void:
	#attack_button.pressed.connect(_on_attack_pressed)
#	Create buttons for moves of active pokemon
	var active_pokemon = BattleStateManager.get_active_pokemon()
	
	if not active_pokemon:
		return
	
	var template_id = Global.get_template_id(active_pokemon.cardStoreData)
	
	var card_data = BattleStateManager.set_registry.get(active_pokemon.cardStoreData.set).get(template_id)
	
	for move in card_data.moves:
		#instantiate OptionFrame
		var move_option_frame = option_frame.instantiate()
		actions_container.add_child(move_option_frame)
		#print("NAME", move.name, "DESCRIPTION", move.get("description", ""), "DAMAGE TERM", move.get("damageTerm", ""))
		move_option_frame.setup(move.name, move.get("description", ""), move.get("damageTerm", ""), move.energyCost, move.name + "_" + active_pokemon.cardStoreData.set + "_" + str(int(active_pokemon.cardStoreData.setNumber)))
		#data_name, data_description, data_damage_term, data_energy_cost, data_template_id
	
	close_click_layer.gui_input.connect(_on_close_click_layer_pressed)
	
func _on_close_click_layer_pressed(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()  # Consume the event to prevent propagation
		queue_free()
	
func _on_attack_pressed():
	SignalManager.attack_clicked.emit()
