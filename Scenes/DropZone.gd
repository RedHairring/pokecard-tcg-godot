extends StaticBody2D

# Define the drop zone types
enum DropZoneType {
	BOARD,
	BENCH,
	ACTIVE
}

# Export the property so it can be set in the editor
@export var drop_zone_type: DropZoneType = DropZoneType.BOARD

func _ready():
	# Get references to child nodes
	var collision_shape = $CollisionShape2D
	var color_rect = $ColorRect

	# Create a new unique shape for this instance
	var shape = RectangleShape2D.new()

	# Set different colors and sizes based on drop zone type
	match drop_zone_type:
		DropZoneType.BOARD:
			modulate = Color(Color.MEDIUM_PURPLE, 0.7)
			# Large area for the board
			_set_zone_size(shape, color_rect, Vector2(800, 400))

		DropZoneType.BENCH:
			modulate = Color(Color.ROYAL_BLUE, 0.7)
			# Card-sized for bench slots
			_set_zone_size(shape, color_rect, Vector2(100, 140))

		DropZoneType.ACTIVE:
			modulate = Color(Color.ORANGE_RED, 0.7)
			# Card-sized for active pokemon
			_set_zone_size(shape, color_rect, Vector2(150, 210))

	# Assign the shape AFTER setting its size
	collision_shape.shape = shape

	# Enable debug visualization to see collision shape
	collision_shape.debug_color = Color(1, 0, 0, 0.3)


func _set_zone_size(shape: RectangleShape2D, color_rect: ColorRect, size: Vector2):
	"""Helper function to set both collision shape and visual size"""
	# Set collision shape size
	shape.size = size

	# Set visual rect size
	color_rect.custom_minimum_size = size
	color_rect.offset_left = -size.x / 2
	color_rect.offset_top = -size.y / 2
	color_rect.offset_right = size.x / 2
	color_rect.offset_bottom = size.y / 2

func _process(delta):
	if Global.is_dragging:
		visible = true
	#else:
		#visible = false
