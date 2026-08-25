extends RefCounted


const BatchResultType = preload("res://debug/six_quarter_batch_result.gd")
const BatchSimulatorType = preload("res://debug/six_quarter_batch_simulator.gd")
const EXPECTED_CANONICAL_LINE_COUNT: int = 702


static func run(report: Callable) -> void:
	var first_simulator: BatchSimulatorType = BatchSimulatorType.new()
	var second_simulator: BatchSimulatorType = BatchSimulatorType.new()
	var first: BatchResultType = first_simulator.run()
	var second: BatchResultType = second_simulator.run()
	var injected: BatchResultType = BatchSimulatorType.new().run(true)

	var execution_exact: bool = (
		_batch_counts_are_exact(first)
		and _canonical_order_is_exact(first)
		and not injected.is_successful()
		and injected.get_game_count() == 100
		and injected.get_quarter_count() == 600
		and injected.get_report_count() == 600
		and injected.get_failure_count() == 1
		and injected.get_start_command_count() == 100
		and injected.get_set_command_count() == 600
		and injected.get_advance_command_count() == 600
		and not injected.get_errors().is_empty()
		and injected.get_errors()[0].ends_with("_injected_failure")
	)
	_report(
		report,
		execution_exact,
		"TP-023 batch executes exactly 100 isolated six-quarter games"
	)

	var deterministic_exact: bool = (
		_batch_counts_are_exact(second)
		and _canonical_order_is_exact(second)
		and first.get_canonical_lines() == second.get_canonical_lines()
		and first.get_canonical_text() == second.get_canonical_text()
		and first.get_aggregate_line() == second.get_aggregate_line()
		and first.get_digest() == second.get_digest()
		and first.get_digest() == _sha256(first.get_canonical_text())
		and first.get_digest().length() == 64
		and _is_lower_hex(first.get_digest())
	)
	_report(
		report,
		deterministic_exact,
		"TP-023 batch digest policies and aggregates are deterministic"
	)


## Used only by the runner's explicit --tp023-batch-only branch.
static func run_batch_only(inject_failure: bool = false) -> bool:
	var result: BatchResultType = BatchSimulatorType.new().run(inject_failure)
	for line in result.get_canonical_lines():
		print(line)
	print("[BATCH] policies training_first=%d inference_first=%d" % [
		result.get_training_first_game_count(),
		result.get_inference_first_game_count(),
	])
	print("[BATCH] counts games=%d quarters=%d reports=%d failed=%d" % [
		result.get_game_count(),
		result.get_quarter_count(),
		result.get_report_count(),
		result.get_failure_count(),
	])
	print("[BATCH] commands start=%d set=%d advance=%d" % [
		result.get_start_command_count(),
		result.get_set_command_count(),
		result.get_advance_command_count(),
	])
	print("[BATCH] streams events_unchanged_games=%d market_unchanged_games=%d" % [
		result.get_events_unchanged_game_count(),
		result.get_market_unchanged_game_count(),
	])
	print("[BATCH] aggregate %s" % result.get_aggregate_line())
	print("[BATCH] digest %s" % result.get_digest())
	var errors: Array[String] = result.get_errors()
	if errors.is_empty():
		print("[BATCH] errors none")
	else:
		for error in errors:
			print("[BATCH] error %s" % error)
	return result.is_successful() and errors.is_empty()


static func _batch_counts_are_exact(result: BatchResultType) -> bool:
	return (
		result != null
		and result.is_successful()
		and result.get_success()
		and result.get_game_count() == 100
		and result.get_games_count() == 100
		and result.get_quarter_count() == 600
		and result.get_report_count() == 600
		and result.get_failure_count() == 0
		and result.get_training_first_game_count() == 50
		and result.get_inference_first_game_count() == 50
		and result.get_start_command_count() == 100
		and result.get_set_command_count() == 600
		and result.get_advance_command_count() == 600
		and result.get_events_unchanged_game_count() == 100
		and result.get_market_unchanged_game_count() == 100
		and result.get_errors().is_empty()
		and result.get_aggregate_line() == "aggregate|100|600|600|0|50|50"
	)


static func _canonical_order_is_exact(result: BatchResultType) -> bool:
	if result == null:
		return false
	var lines: Array[String] = result.get_canonical_lines()
	if (
		lines.size() != EXPECTED_CANONICAL_LINE_COUNT
		or lines[0] != BatchSimulatorType.CANONICAL_VERSION
		or lines[lines.size() - 1] != result.get_aggregate_line()
		or result.get_canonical_text() != "\n".join(lines) + "\n"
		or result.get_canonical_text().contains("\r")
	):
		return false
	for ordinal_index in 100:
		var ordinal: int = ordinal_index + 1
		var run_line_index: int = 1 + (ordinal_index * 7)
		var run_fields: PackedStringArray = lines[run_line_index].split("|", false)
		var expected_policy: String = (
			"training_first" if ordinal <= 50 else "inference_first"
		)
		var expected_seed: int = (ordinal_index % 50) + 1
		if (
			run_fields.size() != 21
			or run_fields[0] != "run"
			or run_fields[1] != str(ordinal)
			or run_fields[2] != expected_policy
			or run_fields[3] != str(expected_seed)
			or run_fields[4] != "ok"
			or run_fields[5] != "-"
			or run_fields[6] != "6"
			or run_fields[7] != "6"
			or run_fields[8] != "18"
			or run_fields[19] != str(expected_seed + 4)
			or run_fields[20] != str(expected_seed + 6)
		):
			return false
		for quarter_index in 6:
			var report_fields: PackedStringArray = lines[
				run_line_index + quarter_index + 1
			].split("|", false)
			var quarter: int = quarter_index + 1
			if (
				report_fields.size() != 33
				or report_fields[0] != "report"
				or report_fields[1] != str(ordinal)
				or report_fields[2] != str(quarter)
				or report_fields[3] != str(quarter_index * 3)
				or report_fields[4] != str(quarter * 3)
			):
				return false
			if quarter < 6:
				if (
					report_fields[29] == "-"
					or report_fields[30] == "-"
					or report_fields[31] == "-"
				):
					return false
			elif (
				report_fields[29] != "-"
				or report_fields[30] != "-"
				or report_fields[31] != "-"
			):
				return false
	return true


static func _sha256(value: String) -> String:
	var context: HashingContext = HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(value.to_utf8_buffer()) != OK:
		return ""
	return context.finish().hex_encode()


static func _is_lower_hex(value: String) -> bool:
	if value.is_empty():
		return false
	for index in value.length():
		var code: int = value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


static func _report(report: Callable, condition: bool, description: String) -> void:
	report.call(condition, description)
