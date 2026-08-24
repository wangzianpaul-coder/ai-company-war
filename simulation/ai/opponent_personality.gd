class_name OpponentPersonality
extends RefCounted


const CANDIDATE_PLAN_40_DEFEND_MARKETS: StringName = &"plan_40_defend_markets"
const CANDIDATE_PLAN_70_CLOSE_TRAINING_GAP: StringName = &"plan_70_close_training_gap"
const REASON_DEFEND_MARKET_POSITION: StringName = &"defend_market_position"
const REASON_CLOSE_TRAINING_GAP: StringName = &"close_training_gap"
const UTILITY_RULE_DEFEND_MARKETS: StringName = &"defend_markets"
const UTILITY_RULE_CLOSE_TRAINING_GAP: StringName = &"close_training_gap"


class Candidate:
	extends RefCounted

	var _candidate_key: StringName
	var _training_units: int
	var _reason_key: StringName
	var _utility_rule_key: StringName

	func _init(
		p_candidate_key: StringName,
		p_training_units: int,
		p_reason_key: StringName,
		p_utility_rule_key: StringName
	) -> void:
		_candidate_key = p_candidate_key
		_training_units = p_training_units
		_reason_key = p_reason_key
		_utility_rule_key = p_utility_rule_key

	func copy() -> Candidate:
		return Candidate.new(
			_candidate_key,
			_training_units,
			_reason_key,
			_utility_rule_key
		)

	func get_candidate_key() -> StringName:
		return _candidate_key

	func get_training_units() -> int:
		return _training_units

	func get_reason_key() -> StringName:
		return _reason_key

	func get_utility_rule_key() -> StringName:
		return _utility_rule_key


var _opponent_id: StringName
var _display_name: String
var _candidates: Array[Candidate] = []
var _defend_base_points: int
var _defend_share_divisor_bps: int
var _train_base_points: int
var _training_target_compute_unit_months: int


## Copies an injected profile so later caller-side Array changes cannot affect decisions.
func _init(
	p_opponent_id: StringName,
	p_display_name: String,
	p_candidates: Array[Candidate],
	p_defend_base_points: int,
	p_defend_share_divisor_bps: int,
	p_train_base_points: int,
	p_training_target_compute_unit_months: int
) -> void:
	_opponent_id = p_opponent_id
	_display_name = p_display_name
	for candidate in p_candidates:
		_candidates.append(null if candidate == null else candidate.copy())
	_defend_base_points = p_defend_base_points
	_defend_share_divisor_bps = p_defend_share_divisor_bps
	_train_base_points = p_train_base_points
	_training_target_compute_unit_months = p_training_target_compute_unit_months


func get_opponent_id() -> StringName:
	return _opponent_id


func get_display_name() -> String:
	return _display_name


func get_candidates() -> Array[Candidate]:
	var copied_candidates: Array[Candidate] = []
	for candidate in _candidates:
		copied_candidates.append(null if candidate == null else candidate.copy())
	return copied_candidates


func get_defend_base_points() -> int:
	return _defend_base_points


func get_defend_share_divisor_bps() -> int:
	return _defend_share_divisor_bps


func get_train_base_points() -> int:
	return _train_base_points


func get_training_target_compute_unit_months() -> int:
	return _training_target_compute_unit_months
