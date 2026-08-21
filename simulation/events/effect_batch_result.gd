class_name EffectBatchResult
extends RefCounted


const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")

## Small failure set for one Finance or Project operation.
enum ErrorCode {
	NONE,
	INVALID_STATE,
	ARITHMETIC_OVERFLOW,
}

var _is_successful: bool
var _error_code: ErrorCode
var _contributions: Array[EffectContributionType] = []


## Stores ordered contributions only for a successful, fully committed operation.
func _init(
	p_error_code: ErrorCode,
	p_contributions: Array[EffectContributionType]
) -> void:
	_error_code = p_error_code
	_is_successful = p_error_code == ErrorCode.NONE
	if _is_successful:
		for contribution in p_contributions:
			_contributions.append(contribution)


func is_successful() -> bool:
	return _is_successful


func get_error_code() -> ErrorCode:
	return _error_code


## Returns a typed copy so callers cannot reorder the stored explanation.
func get_contributions() -> Array[EffectContributionType]:
	var copied_contributions: Array[EffectContributionType] = []
	for contribution in _contributions:
		copied_contributions.append(contribution)
	return copied_contributions
