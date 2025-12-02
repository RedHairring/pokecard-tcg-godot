extends Node


func _ready() -> void:
	SignalManager.attack_clicked.connect(_on_attack_clicked)

func _on_attack_clicked():
	print("ATTACK CLICKED")
