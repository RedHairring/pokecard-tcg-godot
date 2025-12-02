extends CanvasLayer

@export var attack_interface_scene: PackedScene

func _ready() -> void:
	SignalManager.active_pokemon_clicked.connect(show_attack_interface)
	
func show_attack_interface():
	var attack_interface = attack_interface_scene.instantiate()
	add_child(attack_interface)
	var tween = create_tween()
	tween.tween_property(attack_interface, "position:x", 0, 0.2)
	pass
