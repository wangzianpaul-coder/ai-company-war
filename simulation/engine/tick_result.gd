class_name TickResult
extends RefCounted


const GameStateType = preload("res://simulation/state/game_state.gd")
const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")

var _is_successful: bool = false
var _resulting_state: GameStateType
var _contributions: Array[EffectContributionType] = []


## Stores an independent successful result, or an empty failure when state is null.
func _init(
	p_resulting_state: GameStateType,
	p_contributions: Array[EffectContributionType]
) -> void:
	if p_resulting_state == null:
		return

	var copied_state: GameStateType = p_resulting_state.copy()
	if copied_state == null:
		return

	_is_successful = true
	_resulting_state = copied_state
	for contribution in p_contributions:
		_contributions.append(contribution)


func is_successful() -> bool:
	return _is_successful


## Returns a new state copy so callers cannot change the stored successful result.
func get_state_snapshot() -> GameStateType:
	if not _is_successful:
		return null
	return _resulting_state.copy()


## Returns a typed copy preserving the original contribution order.
func get_contributions() -> Array[EffectContributionType]:
	var copied_contributions: Array[EffectContributionType] = []
	for contribution in _contributions:
		copied_contributions.append(contribution)
	return copied_contributions
