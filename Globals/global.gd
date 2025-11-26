extends Node

enum CardSize {SMALL, MEDIUM, LARGE}
const CARD_ORIGINAL_SIZE = Vector2(600, 840)

var is_dragging = false

func get_template_id(card_store_data):
	return card_store_data.name + "_" + card_store_data.set + "_" + str(int(card_store_data.setNumber))
	
func get_scale_from_size(location_type: String) -> Vector2:
	var target_size = get_size(location_type)
	return target_size / CARD_ORIGINAL_SIZE
	
func get_size(location: String):
	match location:
		"active":
			return get_size_dimensions(CardSize.LARGE)
		"bench":
			return get_size_dimensions(CardSize.MEDIUM)
		"hand":
			return get_size_dimensions(CardSize.MEDIUM)
		"discard":
			return get_size_dimensions(CardSize.SMALL)

func get_size_dimensions(size) -> Vector2:
	match size:
		CardSize.SMALL:
			return Vector2(70, 98)
		CardSize.MEDIUM:
			return Vector2(100, 140)
		CardSize.LARGE:
			return Vector2(150, 210)
		_:
			return Vector2(100, 140) #
