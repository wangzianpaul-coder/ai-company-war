extends RefCounted


const ComputeStateType = preload("res://simulation/state/compute_state.gd")
const GameStateType = preload("res://simulation/state/game_state.gd")
const ComputeSystemType = preload("res://simulation/systems/compute_system.gd")
const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")
const EffectBatchResultType = preload("res://simulation/events/effect_batch_result.gd")
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807


static func run(report: Callable) -> void:
	_test_full_copy_isolation(report)
	_test_allocation_boundaries(report)
	_test_fixed_monthly_plans(report)
	_test_cumulative_overflow(report)
	_test_deterministic_sweep(report)


static func _test_full_copy_isolation(report: Callable) -> void:
	var source_compute: ComputeStateType = ComputeStateType.new(100, 10, 50, 40, 7, 8, 9)
	var source_state: GameStateType = GameStateType.new(null, null, source_compute)
	var copied_state: GameStateType = source_state.copy()
	var copied_compute: ComputeStateType = copied_state.get_compute()
	var system: ComputeSystemType = ComputeSystemType.new()
	var copied_changed: bool = (
		system.set_training_allocation(copied_compute, 70).is_successful()
		and system.advance_month(copied_compute).is_successful()
	)
	var source_unchanged: bool = _fields_match(source_state.get_compute(), [
		100, 10, 50, 40, 7, 8, 9,
	])
	var source_changed: bool = (
		system.set_training_allocation(source_state.get_compute(), 0).is_successful()
		and system.advance_month(source_state.get_compute()).is_successful()
	)
	var copy_unchanged_after_source: bool = _fields_match(copied_compute, [
		100, 10, 50, 70, 77, 28, 39,
	])
	_report(
		report,
		copied_state != null
			and copied_compute != source_state.get_compute()
			and copied_changed
			and source_unchanged
			and source_changed
			and copy_unchanged_after_source,
		"TP-020 ComputeState copies every field with bidirectional isolation"
	)


static func _test_allocation_boundaries(report: Callable) -> void:
	var system: ComputeSystemType = ComputeSystemType.new()
	var state: ComputeStateType = ComputeStateType.new(100, 10, 50, 40, 1, 2, 3)
	var zero_result: EffectBatchResultType = system.set_training_allocation(state, 0)
	var maximum_result: EffectBatchResultType = system.set_training_allocation(state, 90)
	var boundary_success: bool = (
		zero_result.is_successful()
		and zero_result.get_contributions().is_empty()
		and maximum_result.is_successful()
		and maximum_result.get_contributions().is_empty()
		and _fields_match(state, [100, 10, 50, 90, 1, 2, 3])
		and state.get_inference_allocation_units_per_month() == 0
	)
	var before_rejections: ComputeStateType = state.copy()
	var negative_result: EffectBatchResultType = system.set_training_allocation(state, -1)
	var over_result: EffectBatchResultType = system.set_training_allocation(state, 91)
	var null_state: ComputeStateType = null
	var null_result: EffectBatchResultType = system.set_training_allocation(null_state, 0)
	var invalid_state: ComputeStateType = ComputeStateType.new(100, 101, 50, 0)
	var invalid_before: ComputeStateType = invalid_state.copy()
	var invalid_result: EffectBatchResultType = system.set_training_allocation(
		invalid_state,
		0
	)
	var rejections_atomic: bool = (
		_is_failed_empty(negative_result, EffectBatchResultType.ErrorCode.INVALID_STATE)
		and _is_failed_empty(over_result, EffectBatchResultType.ErrorCode.INVALID_STATE)
		and _is_failed_empty(null_result, EffectBatchResultType.ErrorCode.INVALID_STATE)
		and _is_failed_empty(invalid_result, EffectBatchResultType.ErrorCode.INVALID_STATE)
		and _states_equal(state, before_rejections)
		and _states_equal(invalid_state, invalid_before)
	)
	_report(
		report,
		boundary_success and rejections_atomic,
		"TP-020 compute allocation validates boundaries atomically"
	)


static func _test_fixed_monthly_plans(report: Callable) -> void:
	var system: ComputeSystemType = ComputeSystemType.new()
	var default_state: ComputeStateType = ComputeStateType.new(100, 10, 50, 40)
	var default_trace: Array[EffectContributionType] = []
	var default_success: bool = true
	for _month_index in 3:
		var result: EffectBatchResultType = system.advance_month(default_state)
		default_success = result.is_successful() and default_success
		_append(default_trace, result.get_contributions())
	var default_exact: bool = (
		default_success
		and _fields_match(default_state, [100, 10, 50, 40, 120, 150, 0])
		and default_trace.size() == 6
	)
	for month_index in 3:
		default_exact = (
			_effect_matches(
				default_trace[month_index * 2],
				EffectContributionType.REASON_TRAINING_WORK,
				40
			)
			and _effect_matches(
				default_trace[(month_index * 2) + 1],
				EffectContributionType.REASON_INFERENCE_SERVED,
				50
			)
			and default_exact
		)

	var constrained_state: ComputeStateType = ComputeStateType.new(100, 10, 50, 70)
	var constrained_trace: Array[EffectContributionType] = []
	var constrained_success: bool = true
	for _month_index in 3:
		var result: EffectBatchResultType = system.advance_month(constrained_state)
		constrained_success = result.is_successful() and constrained_success
		_append(constrained_trace, result.get_contributions())
	var constrained_exact: bool = (
		constrained_success
		and _fields_match(constrained_state, [100, 10, 50, 70, 210, 60, 90])
		and constrained_trace.size() == 9
	)
	for month_index in 3:
		constrained_exact = (
			_effect_matches(
				constrained_trace[month_index * 3],
				EffectContributionType.REASON_TRAINING_WORK,
				70
			)
			and _effect_matches(
				constrained_trace[(month_index * 3) + 1],
				EffectContributionType.REASON_INFERENCE_SERVED,
				20
			)
			and _effect_matches(
				constrained_trace[(month_index * 3) + 2],
				EffectContributionType.REASON_INFERENCE_UNMET,
				30
			)
			and constrained_exact
		)

	var zero_state: ComputeStateType = ComputeStateType.new()
	var zero_result: EffectBatchResultType = system.advance_month(zero_state)
	var zero_inert: bool = (
		zero_result.is_successful()
		and zero_result.get_contributions().is_empty()
		and _fields_match(zero_state, [0, 0, 0, 0, 0, 0, 0])
	)
	_report(
		report,
		default_exact and constrained_exact and zero_inert,
		"TP-020 fixed monthly plans reconcile without banking capacity"
	)


static func _test_cumulative_overflow(report: Callable) -> void:
	var system: ComputeSystemType = ComputeSystemType.new()
	var overflow_states: Array[ComputeStateType] = [
		ComputeStateType.new(1, 0, 0, 1, MAX_SIGNED_INT, 0, 0),
		ComputeStateType.new(1, 0, 1, 0, 0, MAX_SIGNED_INT, 0),
		ComputeStateType.new(0, 0, 1, 0, 0, 0, MAX_SIGNED_INT),
	]
	var all_atomic: bool = true
	for state in overflow_states:
		var before: ComputeStateType = state.copy()
		var result: EffectBatchResultType = system.advance_month(state)
		all_atomic = (
			_is_failed_empty(result, EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
			and _states_equal(state, before)
			and all_atomic
		)
	_report(
		report,
		all_atomic,
		"TP-020 compute cumulative overflow preserves all fields and effects"
	)


static func _test_deterministic_sweep(report: Callable) -> void:
	var system: ComputeSystemType = ComputeSystemType.new()
	var all_deterministic: bool = true
	for case_index in 100:
		var allocation: int = case_index % 91
		var first: ComputeStateType = ComputeStateType.new(100, 10, 50, 40)
		var second: ComputeStateType = ComputeStateType.new(100, 10, 50, 40)
		var first_allocation: EffectBatchResultType = system.set_training_allocation(
			first,
			allocation
		)
		var second_allocation: EffectBatchResultType = system.set_training_allocation(
			second,
			allocation
		)
		var first_month: EffectBatchResultType = system.advance_month(first)
		var second_month: EffectBatchResultType = system.advance_month(second)
		all_deterministic = (
			first_allocation.is_successful()
			and second_allocation.is_successful()
			and first_month.is_successful()
			and second_month.is_successful()
			and first.get_training_allocation_units_per_month()
				+ first.get_inference_allocation_units_per_month()
				+ first.get_reserve_units_per_month()
				== first.get_total_units_per_month()
			and first.get_cumulative_served_inference_compute_unit_months()
				+ first.get_cumulative_unmet_inference_compute_unit_months()
				== 50
			and _states_equal(first, second)
			and _traces_equal(
				first_month.get_contributions(),
				second_month.get_contributions()
			)
			and all_deterministic
		)
	_report(
		report,
		all_deterministic,
		"TP-020 deterministic 100-case allocation sweep remains legal"
	)


static func _fields_match(state: ComputeStateType, expected: Array) -> bool:
	return (
		state != null
		and state.get_total_units_per_month() == expected[0]
		and state.get_reserve_units_per_month() == expected[1]
		and state.get_inference_workload_units_per_month() == expected[2]
		and state.get_training_allocation_units_per_month() == expected[3]
		and state.get_cumulative_training_compute_unit_months() == expected[4]
		and state.get_cumulative_served_inference_compute_unit_months() == expected[5]
		and state.get_cumulative_unmet_inference_compute_unit_months() == expected[6]
	)


static func _states_equal(first: ComputeStateType, second: ComputeStateType) -> bool:
	if first == null or second == null:
		return first == second
	return _fields_match(second, [
		first.get_total_units_per_month(),
		first.get_reserve_units_per_month(),
		first.get_inference_workload_units_per_month(),
		first.get_training_allocation_units_per_month(),
		first.get_cumulative_training_compute_unit_months(),
		first.get_cumulative_served_inference_compute_unit_months(),
		first.get_cumulative_unmet_inference_compute_unit_months(),
	])


static func _is_failed_empty(result: EffectBatchResultType, error_code: int) -> bool:
	return (
		result != null
		and not result.is_successful()
		and result.get_error_code() == error_code
		and result.get_contributions().is_empty()
	)


static func _append(
	target: Array[EffectContributionType],
	source: Array[EffectContributionType]
) -> void:
	for contribution in source:
		target.append(contribution)


static func _effect_matches(
	effect: EffectContributionType,
	reason_key: StringName,
	delta: int
) -> bool:
	var expected_metric: StringName
	match reason_key:
		EffectContributionType.REASON_TRAINING_WORK:
			expected_metric = (
				EffectContributionType.METRIC_CUMULATIVE_TRAINING_COMPUTE_UNIT_MONTHS
			)
		EffectContributionType.REASON_INFERENCE_SERVED:
			expected_metric = (
				EffectContributionType.METRIC_CUMULATIVE_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS
			)
		EffectContributionType.REASON_INFERENCE_UNMET:
			expected_metric = (
				EffectContributionType.METRIC_CUMULATIVE_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS
			)
		_:
			return false
	return (
		effect.get_source_key() == EffectContributionType.SOURCE_COMPUTE
		and effect.get_reason_key() == reason_key
		and effect.get_subject_key() == EffectContributionType.SUBJECT_COMPANY
		and effect.get_metric_key() == expected_metric
		and effect.get_unit() == EffectContributionType.Unit.COMPUTE_UNIT_MONTHS
		and effect.get_delta() == delta
	)


static func _traces_equal(
	first: Array[EffectContributionType],
	second: Array[EffectContributionType]
) -> bool:
	if first.size() != second.size():
		return false
	for index in first.size():
		if (
			first[index].get_source_key() != second[index].get_source_key()
			or first[index].get_reason_key() != second[index].get_reason_key()
			or first[index].get_subject_key() != second[index].get_subject_key()
			or first[index].get_metric_key() != second[index].get_metric_key()
			or first[index].get_unit() != second[index].get_unit()
			or first[index].get_delta() != second[index].get_delta()
		):
			return false
	return true


static func _report(report: Callable, condition: bool, description: String) -> void:
	report.call(condition, description)
