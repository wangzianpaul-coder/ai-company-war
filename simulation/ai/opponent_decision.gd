class_name OpponentDecision
extends RefCounted


const SetComputeAllocationCommandType = preload(
	"res://simulation/commands/set_compute_allocation_command.gd"
)
const NamedRngStateType = preload("res://simulation/rng/named_rng_state.gd")

enum ErrorCode {
	NONE,
	INVALID_STATE,
	ARITHMETIC_OVERFLOW,
	NO_LEGAL_CANDIDATE,
}

var _error_code: ErrorCode
var _command: SetComputeAllocationCommandType
var _candidate_key: StringName
var _reason_key: StringName
var _base_utility_points: int
var _noise_points: int
var _total_utility_points: int
var _proposed_rng_state: NamedRngStateType


## Stores a complete success or a typed empty failure without sharing RNG ownership.
func _init(
	p_error_code: ErrorCode,
	p_command: SetComputeAllocationCommandType = null,
	p_candidate_key: StringName = &"",
	p_reason_key: StringName = &"",
	p_base_utility_points: int = 0,
	p_noise_points: int = 0,
	p_total_utility_points: int = 0,
	p_proposed_rng_state: NamedRngStateType = null
) -> void:
	_error_code = p_error_code
	if p_error_code != ErrorCode.NONE:
		return
	if (
		p_command == null
		or p_command.get_script() != SetComputeAllocationCommandType
		or p_proposed_rng_state == null
	):
		_error_code = ErrorCode.INVALID_STATE
		return
	var rng_copy: NamedRngStateType = p_proposed_rng_state.copy()
	if rng_copy == null:
		_error_code = ErrorCode.INVALID_STATE
		return
	_command = SetComputeAllocationCommandType.new(
		p_command.get_training_units_per_month()
	)
	_candidate_key = p_candidate_key
	_reason_key = p_reason_key
	_base_utility_points = p_base_utility_points
	_noise_points = p_noise_points
	_total_utility_points = p_total_utility_points
	_proposed_rng_state = rng_copy


func is_successful() -> bool:
	return _error_code == ErrorCode.NONE


func get_error_code() -> ErrorCode:
	return _error_code


## Returns a fresh exact command so callers cannot substitute a derived command.
func get_command() -> SetComputeAllocationCommandType:
	if not is_successful():
		return null
	return SetComputeAllocationCommandType.new(
		_command.get_training_units_per_month()
	)


func get_candidate_key() -> StringName:
	return _candidate_key


func get_reason_key() -> StringName:
	return _reason_key


func get_base_utility_points() -> int:
	return _base_utility_points


func get_noise_points() -> int:
	return _noise_points


func get_total_utility_points() -> int:
	return _total_utility_points


func get_proposed_rng_state() -> NamedRngStateType:
	if not is_successful():
		return null
	return _proposed_rng_state.copy()
