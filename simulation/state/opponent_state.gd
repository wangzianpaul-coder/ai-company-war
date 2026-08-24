class_name OpponentState
extends RefCounted


const ComputeStateType = preload("res://simulation/state/compute_state.gd")
const NORTHSTAR_LABS_ID: StringName = &"northstar_labs"

var _opponent_id: StringName
var _compute: ComputeStateType
var _last_candidate_key: StringName
var _last_training_units_per_month: int
var _last_reason_key: StringName
var _last_base_utility_points: int
var _last_noise_points: int
var _last_total_utility_points: int


## Owns an independent Compute posture plus the last committed decision metadata.
## The default is the exact canonical inactive opponent.
func _init(
	p_opponent_id: StringName = &"",
	p_compute: ComputeStateType = null,
	p_last_candidate_key: StringName = &"",
	p_last_training_units_per_month: int = 0,
	p_last_reason_key: StringName = &"",
	p_last_base_utility_points: int = 0,
	p_last_noise_points: int = 0,
	p_last_total_utility_points: int = 0
) -> void:
	_opponent_id = p_opponent_id
	_compute = ComputeStateType.new() if p_compute == null else p_compute.copy()
	_last_candidate_key = p_last_candidate_key
	_last_training_units_per_month = p_last_training_units_per_month
	_last_reason_key = p_last_reason_key
	_last_base_utility_points = p_last_base_utility_points
	_last_noise_points = p_last_noise_points
	_last_total_utility_points = p_last_total_utility_points


func copy():
	return new(
		_opponent_id,
		_compute,
		_last_candidate_key,
		_last_training_units_per_month,
		_last_reason_key,
		_last_base_utility_points,
		_last_noise_points,
		_last_total_utility_points
	)


func get_opponent_id() -> StringName:
	return _opponent_id


func get_compute() -> ComputeStateType:
	return _compute


func get_last_candidate_key() -> StringName:
	return _last_candidate_key


func get_last_training_units_per_month() -> int:
	return _last_training_units_per_month


func get_last_reason_key() -> StringName:
	return _last_reason_key


func get_last_base_utility_points() -> int:
	return _last_base_utility_points


func get_last_noise_points() -> int:
	return _last_noise_points


func get_last_total_utility_points() -> int:
	return _last_total_utility_points


## Commits metadata only after the legal allocation and complete decision succeed.
func _commit_decision(
	p_candidate_key: StringName,
	p_training_units_per_month: int,
	p_reason_key: StringName,
	p_base_utility_points: int,
	p_noise_points: int,
	p_total_utility_points: int
) -> void:
	_last_candidate_key = p_candidate_key
	_last_training_units_per_month = p_training_units_per_month
	_last_reason_key = p_reason_key
	_last_base_utility_points = p_base_utility_points
	_last_noise_points = p_noise_points
	_last_total_utility_points = p_total_utility_points
