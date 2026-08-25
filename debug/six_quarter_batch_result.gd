class_name SixQuarterBatchResult
extends RefCounted


var _is_successful: bool
var _game_count: int
var _quarter_count: int
var _report_count: int
var _failure_count: int
var _training_first_game_count: int
var _inference_first_game_count: int
var _start_command_count: int
var _set_command_count: int
var _advance_command_count: int
var _events_unchanged_game_count: int
var _market_unchanged_game_count: int
var _canonical_text: String
var _canonical_lines: Array[String] = []
var _digest: String
var _aggregate_line: String
var _errors: Array[String] = []


## Owns primitive batch evidence. Arrays are copied on input and output.
func _init(
	p_is_successful: bool,
	p_game_count: int,
	p_quarter_count: int,
	p_report_count: int,
	p_failure_count: int,
	p_training_first_game_count: int,
	p_inference_first_game_count: int,
	p_start_command_count: int,
	p_set_command_count: int,
	p_advance_command_count: int,
	p_events_unchanged_game_count: int,
	p_market_unchanged_game_count: int,
	p_canonical_text: String,
	p_canonical_lines: Array[String],
	p_digest: String,
	p_aggregate_line: String,
	p_errors: Array[String]
) -> void:
	_is_successful = p_is_successful
	_game_count = p_game_count
	_quarter_count = p_quarter_count
	_report_count = p_report_count
	_failure_count = p_failure_count
	_training_first_game_count = p_training_first_game_count
	_inference_first_game_count = p_inference_first_game_count
	_start_command_count = p_start_command_count
	_set_command_count = p_set_command_count
	_advance_command_count = p_advance_command_count
	_events_unchanged_game_count = p_events_unchanged_game_count
	_market_unchanged_game_count = p_market_unchanged_game_count
	_canonical_text = p_canonical_text
	for line in p_canonical_lines:
		_canonical_lines.append(line)
	_digest = p_digest
	_aggregate_line = p_aggregate_line
	for error in p_errors:
		_errors.append(error)


func copy():
	return new(
		_is_successful,
		_game_count,
		_quarter_count,
		_report_count,
		_failure_count,
		_training_first_game_count,
		_inference_first_game_count,
		_start_command_count,
		_set_command_count,
		_advance_command_count,
		_events_unchanged_game_count,
		_market_unchanged_game_count,
		_canonical_text,
		_canonical_lines,
		_digest,
		_aggregate_line,
		_errors
	)


func is_successful() -> bool:
	return _is_successful


func get_success() -> bool:
	return _is_successful


func get_game_count() -> int:
	return _game_count


func get_games_count() -> int:
	return _game_count


func get_quarter_count() -> int:
	return _quarter_count


func get_report_count() -> int:
	return _report_count


func get_failure_count() -> int:
	return _failure_count


func get_failures_count() -> int:
	return _failure_count


func get_training_first_game_count() -> int:
	return _training_first_game_count


func get_inference_first_game_count() -> int:
	return _inference_first_game_count


func get_policy_game_count(policy_key: StringName) -> int:
	if policy_key == &"training_first":
		return _training_first_game_count
	if policy_key == &"inference_first":
		return _inference_first_game_count
	return 0


func get_start_command_count() -> int:
	return _start_command_count


func get_start_commands_count() -> int:
	return _start_command_count


func get_set_command_count() -> int:
	return _set_command_count


func get_set_commands_count() -> int:
	return _set_command_count


func get_advance_command_count() -> int:
	return _advance_command_count


func get_advance_commands_count() -> int:
	return _advance_command_count


func get_events_unchanged_game_count() -> int:
	return _events_unchanged_game_count


func get_events_stream_unchanged_game_count() -> int:
	return _events_unchanged_game_count


func get_market_unchanged_game_count() -> int:
	return _market_unchanged_game_count


func get_market_stream_unchanged_game_count() -> int:
	return _market_unchanged_game_count


func get_canonical_text() -> String:
	return _canonical_text


func get_canonical_lines() -> Array[String]:
	var copied: Array[String] = []
	for line in _canonical_lines:
		copied.append(line)
	return copied


func get_digest() -> String:
	return _digest


func get_aggregate_line() -> String:
	return _aggregate_line


func get_errors() -> Array[String]:
	var copied: Array[String] = []
	for error in _errors:
		copied.append(error)
	return copied
