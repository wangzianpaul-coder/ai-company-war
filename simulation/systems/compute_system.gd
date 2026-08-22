class_name ComputeSystem
extends RefCounted


const ComputeStateType = preload("res://simulation/state/compute_state.gd")
const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")
const EffectBatchResultType = preload("res://simulation/events/effect_batch_result.gd")
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807


## Changes only the monthly split; inference remains the derived remainder.
func set_training_allocation(
	compute_state: ComputeStateType,
	training_units_per_month: int
) -> EffectBatchResultType:
	if not _is_compute_state_valid(compute_state):
		return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)
	if (
		training_units_per_month < 0
		or training_units_per_month > compute_state.get_allocatable_capacity_units_per_month()
	):
		return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)

	compute_state._commit_training_allocation(training_units_per_month)
	var no_contributions: Array[EffectContributionType] = []
	return EffectBatchResultType.new(EffectBatchResultType.ErrorCode.NONE, no_contributions)


## Settles one non-bankable capacity month in training, served, unmet order.
## All cumulative additions are checked before state or effects are committed.
func advance_month(compute_state: ComputeStateType) -> EffectBatchResultType:
	if not _is_compute_state_valid(compute_state):
		return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)

	var training_work: int = compute_state.get_training_allocation_units_per_month()
	var served_inference: int = compute_state.get_served_inference_units_per_month()
	var unmet_inference: int = compute_state.get_unmet_inference_units_per_month()

	var cumulative_training: int = (
		compute_state.get_cumulative_training_compute_unit_months()
	)
	var cumulative_served: int = (
		compute_state.get_cumulative_served_inference_compute_unit_months()
	)
	var cumulative_unmet: int = (
		compute_state.get_cumulative_unmet_inference_compute_unit_months()
	)
	if (
		not _can_add_non_negative(cumulative_training, training_work)
		or not _can_add_non_negative(cumulative_served, served_inference)
		or not _can_add_non_negative(cumulative_unmet, unmet_inference)
	):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)

	var training_after: int = cumulative_training + training_work
	var served_after: int = cumulative_served + served_inference
	var unmet_after: int = cumulative_unmet + unmet_inference
	var contributions: Array[EffectContributionType] = []
	if training_work != 0:
		contributions.append(EffectContributionType.new(
			EffectContributionType.SOURCE_COMPUTE,
			EffectContributionType.REASON_TRAINING_WORK,
			EffectContributionType.SUBJECT_COMPANY,
			EffectContributionType.METRIC_CUMULATIVE_TRAINING_COMPUTE_UNIT_MONTHS,
			EffectContributionType.Unit.COMPUTE_UNIT_MONTHS,
			training_work
		))
	if served_inference != 0:
		contributions.append(EffectContributionType.new(
			EffectContributionType.SOURCE_COMPUTE,
			EffectContributionType.REASON_INFERENCE_SERVED,
			EffectContributionType.SUBJECT_COMPANY,
			EffectContributionType.METRIC_CUMULATIVE_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS,
			EffectContributionType.Unit.COMPUTE_UNIT_MONTHS,
			served_inference
		))
	if unmet_inference != 0:
		contributions.append(EffectContributionType.new(
			EffectContributionType.SOURCE_COMPUTE,
			EffectContributionType.REASON_INFERENCE_UNMET,
			EffectContributionType.SUBJECT_COMPANY,
			EffectContributionType.METRIC_CUMULATIVE_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS,
			EffectContributionType.Unit.COMPUTE_UNIT_MONTHS,
			unmet_inference
		))

	compute_state._commit_cumulative_results(training_after, served_after, unmet_after)
	return EffectBatchResultType.new(EffectBatchResultType.ErrorCode.NONE, contributions)


func _failed(error_code: EffectBatchResultType.ErrorCode) -> EffectBatchResultType:
	var no_contributions: Array[EffectContributionType] = []
	return EffectBatchResultType.new(error_code, no_contributions)


func _is_compute_state_valid(compute_state: ComputeStateType) -> bool:
	if compute_state == null:
		return false
	if (
		compute_state.get_total_units_per_month() < 0
		or compute_state.get_reserve_units_per_month() < 0
		or compute_state.get_inference_workload_units_per_month() < 0
		or compute_state.get_training_allocation_units_per_month() < 0
		or compute_state.get_cumulative_training_compute_unit_months() < 0
		or compute_state.get_cumulative_served_inference_compute_unit_months() < 0
		or compute_state.get_cumulative_unmet_inference_compute_unit_months() < 0
	):
		return false
	if compute_state.get_reserve_units_per_month() > compute_state.get_total_units_per_month():
		return false
	return (
		compute_state.get_training_allocation_units_per_month()
		<= compute_state.get_allocatable_capacity_units_per_month()
	)


func _can_add_non_negative(value: int, delta: int) -> bool:
	return value >= 0 and delta >= 0 and value <= MAX_SIGNED_INT - delta
