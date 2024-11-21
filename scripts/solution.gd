extends Node

@onready var manager :Manager = get_parent()


func _ready():
	manager.set_speed(10)
	
	await get_tree().create_timer(3).timeout
	
	manager.set_speed(0)
	manager.end_of_parking()
	
