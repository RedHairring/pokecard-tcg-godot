extends Node2D


@onready var sprite = $Sprite2D

var offset: Vector2
var initialPos: Vector2
var card: Dictionary = {}
var card_size: Vector2 = Vector2(100, 140) # Default medium size

func set_card_data(data: Dictionary):
	card = data
	_load_card_image()
	_resize_card()
	
func _load_card_image():
	var card_store_data = card.cardStoreData
	var template_id = Global.get_template_id(card_store_data)
	#print("TEMPLATE ID", template_id)
	var image_path = "res://assets/BS/%s.png" % template_id
	#print("IMAGE PATH", image_path)
	# Load the texture
	var texture = load(image_path)
	
	if texture:
			sprite.texture = texture
			#print("[DraggableCard] Loaded image: ", image_path)
	else:
			print("[DraggableCard] Failed to load image: ", image_path)
	
func _resize_card():
	card_size = Global.get_size(card.location.type)
	# Get and apply the scale factor
	var scale_factor = Global.get_scale_from_size(card.location.type)
	sprite.scale = scale_factor

	# Update collision shape to match new size
	$Area2D/CollisionShape2D.shape.size = card_size

#func _process(delta):
	
#	Handle active pokemon click
	#if  card.has("location") and card.location.type == 'active' and card.owner == BattleStateManager.current_player_id:
		#print("MOUSE OVER BEFORE", mouse_is_over)
		#if Input.is_action_just_pressed('click'):
			#mouse_is_over = false
			#print("hit open")
			#SignalManager.active_pokemon_clicked.emit()
			#print("MOUSE OVER?", mouse_is_over)
		#pass
		
		
func _on_area_2d_mouse_entered() -> void:
	#if not Global.is_dragging:
	scale = Vector2(1.05, 1.05)

func _on_area_2d_mouse_exited() -> void:
	#if not Global.is_dragging:
	scale = Vector2(1, 1)


func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if card.has("location") and card.location.type == 'active' and card.owner == BattleStateManager.current_player_id:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("Active pokemon clicked, opening attack interface")
			get_viewport().set_input_as_handled()  # Consume the event to prevent propagation
			SignalManager.active_pokemon_clicked.emit()
