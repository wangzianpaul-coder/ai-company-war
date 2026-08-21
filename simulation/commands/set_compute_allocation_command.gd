class_name SetComputeAllocationCommand
extends "res://simulation/commands/game_command.gd"


var _training_units_per_month: int


## Requests one monthly training allocation; Simulation derives the inference remainder.
func _init(p_training_units_per_month: int) -> void:
	_training_units_per_month = p_training_units_per_month


func get_training_units_per_month() -> int:
	return _training_units_per_month
