class_name GameState
extends RefCounted


const SimulationClockType = preload("res://simulation/engine/simulation_clock.gd")

var _clock: SimulationClockType


func _init() -> void:
	_clock = SimulationClockType.new()


## Returns the typed clock owned by this runtime state.
func get_clock() -> SimulationClockType:
	return _clock
