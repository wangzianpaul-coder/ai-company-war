class_name QuarterReport
extends RefCounted


const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807

const METRIC_CASH_CENTS: StringName = &"cash_cents"
const METRIC_COMPANY_MONTHLY_REVENUE_CENTS: StringName = &"company_monthly_revenue_cents"
const METRIC_CONSUMER_PLAYER_SHARE_BPS: StringName = &"consumer_player_share_bps"
const METRIC_CONSUMER_MONTHLY_REVENUE_CENTS: StringName = &"consumer_monthly_revenue_cents"
const METRIC_DEVELOPER_API_PLAYER_SHARE_BPS: StringName = (
	&"developer_api_player_share_bps"
)
const METRIC_DEVELOPER_API_MONTHLY_REVENUE_CENTS: StringName = (
	&"developer_api_monthly_revenue_cents"
)
const METRIC_PLAYER_TRAINING_COMPUTE_UNIT_MONTHS: StringName = (
	&"player_training_compute_unit_months"
)
const METRIC_PLAYER_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS: StringName = (
	&"player_served_inference_compute_unit_months"
)
const METRIC_PLAYER_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS: StringName = (
	&"player_unmet_inference_compute_unit_months"
)

const METRIC_COUNT: int = 9
const MAX_DISPLAYED_CONTRIBUTIONS_PER_METRIC: int = 3

var _is_valid: bool = false
var _quarter_number: int
var _start_elapsed_months: int
var _end_elapsed_months: int
var _before_values: Array[int] = []
var _after_values: Array[int] = []
var _displayed_contributions_by_metric: Array = []
var _contributions: Array[EffectContributionType] = []
var _committed_opponent_id: StringName
var _committed_candidate_key: StringName
var _committed_training_units_per_month: int
var _committed_reason_key: StringName
var _committed_base_utility_points: int
var _committed_noise_points: int
var _committed_total_utility_points: int
var _has_next_signal: bool
var _next_candidate_key: StringName
var _next_training_units_per_month: int
var _next_reason_key: StringName
var _is_prototype_complete: bool


## Owns one committed quarter as primitive facts and fully independent effects.
## Parallel value/display arrays always use get_metric_keys() order.
func _init(
	p_quarter_number: int,
	p_start_elapsed_months: int,
	p_end_elapsed_months: int,
	p_before_values: Array[int],
	p_after_values: Array[int],
	p_displayed_contributions_by_metric: Array,
	p_contributions: Array[EffectContributionType],
	p_committed_opponent_id: StringName,
	p_committed_candidate_key: StringName,
	p_committed_training_units_per_month: int,
	p_committed_reason_key: StringName,
	p_committed_base_utility_points: int,
	p_committed_noise_points: int,
	p_committed_total_utility_points: int,
	p_has_next_signal: bool,
	p_next_candidate_key: StringName,
	p_next_training_units_per_month: int,
	p_next_reason_key: StringName,
	p_is_prototype_complete: bool
) -> void:
	if not _header_is_valid(
		p_quarter_number,
		p_start_elapsed_months,
		p_end_elapsed_months,
		p_is_prototype_complete
	):
		return
	if p_before_values.size() != METRIC_COUNT or p_after_values.size() != METRIC_COUNT:
		return
	if p_displayed_contributions_by_metric.size() != METRIC_COUNT:
		return
	if not _metric_values_are_valid(p_before_values, p_after_values):
		return
	if not _opponent_metadata_is_valid(
		p_committed_opponent_id,
		p_committed_candidate_key,
		p_committed_training_units_per_month,
		p_committed_reason_key,
		p_committed_base_utility_points,
		p_committed_noise_points,
		p_committed_total_utility_points,
		p_has_next_signal,
		p_next_candidate_key,
		p_next_training_units_per_month,
		p_next_reason_key,
		p_is_prototype_complete
	):
		return

	var copied_contributions: Array[EffectContributionType] = _copy_contributions(
		p_contributions
	)
	if copied_contributions.size() != p_contributions.size():
		return
	var copied_displayed: Array = _copy_and_validate_displayed(
		p_displayed_contributions_by_metric,
		p_contributions
	)
	if copied_displayed.size() != METRIC_COUNT:
		return

	_quarter_number = p_quarter_number
	_start_elapsed_months = p_start_elapsed_months
	_end_elapsed_months = p_end_elapsed_months
	_before_values.assign(p_before_values)
	_after_values.assign(p_after_values)
	_displayed_contributions_by_metric = copied_displayed
	_contributions = copied_contributions
	_committed_opponent_id = p_committed_opponent_id
	_committed_candidate_key = p_committed_candidate_key
	_committed_training_units_per_month = p_committed_training_units_per_month
	_committed_reason_key = p_committed_reason_key
	_committed_base_utility_points = p_committed_base_utility_points
	_committed_noise_points = p_committed_noise_points
	_committed_total_utility_points = p_committed_total_utility_points
	_has_next_signal = p_has_next_signal
	_next_candidate_key = p_next_candidate_key
	_next_training_units_per_month = p_next_training_units_per_month
	_next_reason_key = p_next_reason_key
	_is_prototype_complete = p_is_prototype_complete
	_is_valid = true


func is_valid() -> bool:
	return _is_valid


## Returns a fully independent report, including fresh contribution objects.
## No return annotation avoids a static self-reference parser edge case.
func copy():
	if not _is_valid:
		return null
	return new(
		_quarter_number,
		_start_elapsed_months,
		_end_elapsed_months,
		_before_values,
		_after_values,
		_displayed_contributions_by_metric,
		_contributions,
		_committed_opponent_id,
		_committed_candidate_key,
		_committed_training_units_per_month,
		_committed_reason_key,
		_committed_base_utility_points,
		_committed_noise_points,
		_committed_total_utility_points,
		_has_next_signal,
		_next_candidate_key,
		_next_training_units_per_month,
		_next_reason_key,
		_is_prototype_complete
	)


func get_quarter_number() -> int:
	return _quarter_number


func get_start_elapsed_months() -> int:
	return _start_elapsed_months


func get_end_elapsed_months() -> int:
	return _end_elapsed_months


## Returns the nine stable metrics in canonical display/digest order.
func get_metric_keys() -> Array[StringName]:
	return _canonical_metric_keys()


func get_before_value(metric_key: StringName) -> int:
	var metric_index: int = _metric_index(metric_key)
	return 0 if metric_index < 0 or not _is_valid else _before_values[metric_index]


func get_after_value(metric_key: StringName) -> int:
	var metric_index: int = _metric_index(metric_key)
	return 0 if metric_index < 0 or not _is_valid else _after_values[metric_index]


## Returns fresh effect records for one metric's deterministic top-three reasons.
func get_displayed_contributions(
	metric_key: StringName
) -> Array[EffectContributionType]:
	var metric_index: int = _metric_index(metric_key)
	if metric_index < 0 or not _is_valid:
		var empty: Array[EffectContributionType] = []
		return empty
	var stored: Array = _displayed_contributions_by_metric[metric_index]
	return _copy_contributions_from_untyped(stored)


## Flattens displayed reason keys in metric order, preserving duplicates and rank.
func get_all_displayed_reason_keys() -> Array[StringName]:
	var reason_keys: Array[StringName] = []
	if not _is_valid:
		return reason_keys
	for metric_index in METRIC_COUNT:
		var displayed: Array = _displayed_contributions_by_metric[metric_index]
		for contribution_value in displayed:
			var contribution: EffectContributionType = contribution_value
			reason_keys.append(contribution.get_reason_key())
	return reason_keys


## Returns fresh records in the exact committed engine order.
func get_contributions() -> Array[EffectContributionType]:
	if not _is_valid:
		var empty: Array[EffectContributionType] = []
		return empty
	return _copy_contributions(_contributions)


func get_committed_opponent_id() -> StringName:
	return _committed_opponent_id


func get_committed_candidate_key() -> StringName:
	return _committed_candidate_key


func get_committed_training_units_per_month() -> int:
	return _committed_training_units_per_month


func get_committed_reason_key() -> StringName:
	return _committed_reason_key


func get_committed_base_utility_points() -> int:
	return _committed_base_utility_points


func get_committed_noise_points() -> int:
	return _committed_noise_points


func get_committed_total_utility_points() -> int:
	return _committed_total_utility_points


func has_next_signal() -> bool:
	return _has_next_signal


func get_next_candidate_key() -> StringName:
	return _next_candidate_key


func get_next_training_units_per_month() -> int:
	return _next_training_units_per_month


func get_next_reason_key() -> StringName:
	return _next_reason_key


func is_prototype_complete() -> bool:
	return _is_prototype_complete


static func _header_is_valid(
	quarter_number: int,
	start_elapsed_months: int,
	end_elapsed_months: int,
	prototype_complete: bool
) -> bool:
	return (
		quarter_number >= 1
		and quarter_number <= 6
		and prototype_complete == (quarter_number == 6)
		and start_elapsed_months >= 0
		and start_elapsed_months <= MAX_SIGNED_INT - 3
		and end_elapsed_months == start_elapsed_months + 3
	)


static func _metric_values_are_valid(
	before_values: Array[int],
	after_values: Array[int]
) -> bool:
	for metric_index in METRIC_COUNT:
		if metric_index == 0:
			continue
		if before_values[metric_index] < 0 or after_values[metric_index] < 0:
			return false
	return (
		before_values[2] <= 10_000
		and after_values[2] <= 10_000
		and before_values[4] <= 10_000
		and after_values[4] <= 10_000
	)


static func _opponent_metadata_is_valid(
	opponent_id: StringName,
	candidate_key: StringName,
	training_units_per_month: int,
	reason_key: StringName,
	base_utility_points: int,
	noise_points: int,
	total_utility_points: int,
	has_next: bool,
	next_candidate_key: StringName,
	next_training_units_per_month: int,
	next_reason_key: StringName,
	prototype_complete: bool
) -> bool:
	if opponent_id == &"":
		return (
			candidate_key == &""
			and training_units_per_month == 0
			and reason_key == &""
			and base_utility_points == 0
			and noise_points == 0
			and total_utility_points == 0
			and not has_next
			and next_candidate_key == &""
			and next_training_units_per_month == 0
			and next_reason_key == &""
		)
	if (
		candidate_key == &""
		or reason_key == &""
		or training_units_per_month < 0
		or base_utility_points < 0
		or noise_points < 0
		or total_utility_points < 0
		or base_utility_points > MAX_SIGNED_INT - noise_points
		or total_utility_points != base_utility_points + noise_points
	):
		return false
	if prototype_complete:
		return (
			not has_next
			and next_candidate_key == &""
			and next_training_units_per_month == 0
			and next_reason_key == &""
		)
	return (
		has_next
		and next_candidate_key != &""
		and next_training_units_per_month >= 0
		and next_reason_key != &""
	)


static func _canonical_metric_keys() -> Array[StringName]:
	return [
		METRIC_CASH_CENTS,
		METRIC_COMPANY_MONTHLY_REVENUE_CENTS,
		METRIC_CONSUMER_PLAYER_SHARE_BPS,
		METRIC_CONSUMER_MONTHLY_REVENUE_CENTS,
		METRIC_DEVELOPER_API_PLAYER_SHARE_BPS,
		METRIC_DEVELOPER_API_MONTHLY_REVENUE_CENTS,
		METRIC_PLAYER_TRAINING_COMPUTE_UNIT_MONTHS,
		METRIC_PLAYER_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS,
		METRIC_PLAYER_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS,
	]


static func _metric_index(metric_key: StringName) -> int:
	match metric_key:
		METRIC_CASH_CENTS:
			return 0
		METRIC_COMPANY_MONTHLY_REVENUE_CENTS:
			return 1
		METRIC_CONSUMER_PLAYER_SHARE_BPS:
			return 2
		METRIC_CONSUMER_MONTHLY_REVENUE_CENTS:
			return 3
		METRIC_DEVELOPER_API_PLAYER_SHARE_BPS:
			return 4
		METRIC_DEVELOPER_API_MONTHLY_REVENUE_CENTS:
			return 5
		METRIC_PLAYER_TRAINING_COMPUTE_UNIT_MONTHS:
			return 6
		METRIC_PLAYER_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS:
			return 7
		METRIC_PLAYER_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS:
			return 8
	return -1


static func _copy_contributions(
	source: Array[EffectContributionType]
) -> Array[EffectContributionType]:
	var copied: Array[EffectContributionType] = []
	for contribution in source:
		var contribution_copy: EffectContributionType = _copy_contribution(contribution)
		if contribution_copy == null:
			var invalid: Array[EffectContributionType] = []
			return invalid
		copied.append(contribution_copy)
	return copied


static func _copy_contributions_from_untyped(
	source: Array
) -> Array[EffectContributionType]:
	var copied: Array[EffectContributionType] = []
	for contribution_value in source:
		var contribution: EffectContributionType = contribution_value
		var contribution_copy: EffectContributionType = _copy_contribution(contribution)
		if contribution_copy == null:
			var invalid: Array[EffectContributionType] = []
			return invalid
		copied.append(contribution_copy)
	return copied


static func _copy_and_validate_displayed(
	displayed_by_metric: Array,
	all_contributions: Array[EffectContributionType]
) -> Array:
	var copied_by_metric: Array = []
	for metric_index in METRIC_COUNT:
		var displayed_value: Variant = displayed_by_metric[metric_index]
		if typeof(displayed_value) != TYPE_ARRAY:
			return []
		var displayed: Array = displayed_value
		if displayed.size() > MAX_DISPLAYED_CONTRIBUTIONS_PER_METRIC:
			return []
		var used_full_indices: Array[bool] = []
		used_full_indices.resize(all_contributions.size())
		used_full_indices.fill(false)
		var copied_metric: Array[EffectContributionType] = []
		for contribution_value in displayed:
			var contribution: EffectContributionType = contribution_value
			if contribution == null:
				return []
			var matching_index: int = _find_unmatched_contribution(
				contribution,
				all_contributions,
				used_full_indices
			)
			if matching_index < 0:
				return []
			used_full_indices[matching_index] = true
			copied_metric.append(_copy_contribution(contribution))
		copied_by_metric.append(copied_metric)
	return copied_by_metric


static func _find_unmatched_contribution(
	target: EffectContributionType,
	all_contributions: Array[EffectContributionType],
	used_indices: Array[bool]
) -> int:
	for contribution_index in all_contributions.size():
		if (
			not used_indices[contribution_index]
			and _contributions_equal(target, all_contributions[contribution_index])
		):
			return contribution_index
	return -1


static func _contributions_equal(
	first: EffectContributionType,
	second: EffectContributionType
) -> bool:
	return (
		first != null
		and second != null
		and first.get_source_key() == second.get_source_key()
		and first.get_reason_key() == second.get_reason_key()
		and first.get_subject_key() == second.get_subject_key()
		and first.get_metric_key() == second.get_metric_key()
		and first.get_unit() == second.get_unit()
		and first.get_delta() == second.get_delta()
	)


static func _copy_contribution(
	contribution: EffectContributionType
) -> EffectContributionType:
	if contribution == null:
		return null
	return EffectContributionType.new(
		contribution.get_source_key(),
		contribution.get_reason_key(),
		contribution.get_subject_key(),
		contribution.get_metric_key(),
		contribution.get_unit(),
		contribution.get_delta()
	)
