extends Area2D

enum CardSize {SMALL, MEDIUM, LARGE}

@export var size: CardSize = CardSize.MEDIUM
@onready var card_image_sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D

func _ready():
	#pass
	apply_size()
	# Debug: Show collision shapes
	#get_tree().debug_collisions_hint = true
	#print("Collision shape size: ", collision_shape.shape.size)
	#print("Card position: ", global_position)

func apply_size():
	var target_size = get_size_dimensions()

	  # Calculate scale based on original texture size
	if card_image_sprite.texture:
		var original_size = card_image_sprite.texture.get_size()
		var scale_factor = target_size / original_size
		card_image_sprite.scale = scale_factor

		  # Update collision shape to match
	if collision_shape and collision_shape.shape:
		collision_shape.shape.size = target_size

	print("Card size set to: ", CardSize.keys()[size], " (", target_size, ")", card_image_sprite.scale)

func get_size_dimensions() -> Vector2:
	match size:
		CardSize.SMALL:
			return Vector2(70, 98)
		CardSize.MEDIUM:
			return Vector2(100, 140)
		CardSize.LARGE:
			return Vector2(150, 210)
		_:
			return Vector2(100, 140) # Default to medium

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("Card clicked at position: ", global_position)

func _get_drag_data(_position):
	var preview = Sprite2D.new()
	preview.texture = card_image_sprite.texture
	preview.scale = card_image_sprite.scale
	preview.modulate.a = 0.7
	
	var data = {
		"card": self,
		"origin_position": global_position
	}

	return data
