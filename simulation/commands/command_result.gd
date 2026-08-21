class_name CommandResult
extends RefCounted


var _is_successful: bool


## Creates the minimal typed outcome shared by future command boundaries.
func _init(p_is_successful: bool) -> void:
	_is_successful = p_is_successful


## Returns whether the command boundary accepted and completed its work.
func is_successful() -> bool:
	return _is_successful
