extends TextureButton
@onready var label: Label = $Label

var option_name: String
var description: String
var damage_term: String
var energy_cost = []
var template_id: String

func setup(data_name, data_description, data_damage_term, data_energy_cost, data_template_id):
	option_name = data_name
	template_id = data_template_id
	var name_label = Label.new()
	name_label.text = data_name
	name_label.position = Vector2(60, 30)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color.html("#000000"))
	add_child(name_label)
	
	if data_description:
		description = data_description
		var description_label = Label.new()
		
		description_label.position = name_label.position
		description_label.position.y += 20
		description_label.anchor_left = 0.0
		description_label.anchor_right = 1.0
		description_label.offset_left = 60
		description_label.offset_top = 50
		description_label.offset_right = -20
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		description_label.text = description
		description_label.add_theme_font_size_override("font_size", 14)
		description_label.add_theme_color_override("font_color", Color.html("#000000"))
		description_label.custom_minimum_size = Vector2(120, 0) 
		description_label.size = Vector2(120, 0)  
		
		print("Description label size: ", description_label.size)
		print("Description label custom_minimum_size: ", description_label.custom_minimum_size)
		print("Description text: ", description_label.text)
		
		add_child(description_label)
		name_label.position.y -= 20
	if data_energy_cost:
		energy_cost = data_energy_cost
	if data_damage_term:
		damage_term = data_damage_term
	
		
	pass


func _on_pressed() -> void:
	SignalManager.attack_clicked.emit(template_id)
