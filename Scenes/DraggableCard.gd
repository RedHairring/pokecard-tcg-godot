extends Node2D

@onready var sprite = $Sprite2D

var draggable = false
var is_inside_dropable = false
var body_ref
var offset: Vector2
var initialPos: Vector2
var card_data: Dictionary = {}
var card_size: Vector2 = Vector2(100, 140)  # Default medium size


func set_card_data(data: Dictionary):
	card_data = data
	_load_card_image()
	_resize_card()
	
func _load_card_image():
	var card_store_data = card_data.cardStoreData
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
	card_size = Global.get_size(card_data.location.type)
	# Get and apply the scale factor
	var scale_factor = Global.get_scale_from_size(card_data.location.type)
	sprite.scale = scale_factor

	# Update collision shape to match new size
	$Area2D/CollisionShape2D.shape.size = card_size

func _process(delta):
	if draggable:
		if Input.is_action_just_pressed('click'):
			initialPos = global_position
			offset = get_global_mouse_position() - global_position
			Global.is_dragging = true
		if Input.is_action_pressed('click'):
			global_position = get_global_mouse_position()
		elif Input.is_action_just_released('click'):
			Global.is_dragging = false
			var tween = get_tree().create_tween()
			if is_inside_dropable:
				tween.tween_property(self, 'position', body_ref.position, 0.2).set_ease(Tween.EASE_OUT)
			else:
				tween.tween_property(self, 'global_position', initialPos, 0.2).set_ease(Tween.EASE_OUT)
		

func _on_area_2d_mouse_entered() -> void:
	if not Global.is_dragging:
		draggable = true
		scale = Vector2(1.05, 1.05)

func _on_area_2d_mouse_exited() -> void:
	if not Global.is_dragging:
		draggable = false
		scale = Vector2(1, 1)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group('dropable'):
		is_inside_dropable = true
		body.modulate = Color(Color.REBECCA_PURPLE, 1)
		body_ref = body

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group('dropable'):
		is_inside_dropable = false
		body.modulate = Color(Color.MEDIUM_PURPLE, 0.7)
