class_name QuarterReportBuilder
extends RefCounted


const QuarterReportType = preload("res://simulation/reports/quarter_report.gd")
const TickResultType = preload("res://simulation/engine/tick_result.gd")
const GameStateType = preload("res://simulation/state/game_state.gd")
const OpponentStateType = preload("res://simulation/state/opponent_state.gd")
const OpponentDecisionType = preload("res://simulation/ai/opponent_decision.gd")
const SetComputeAllocationCommandType = preload(
	"res://simulation/commands/set_compute_allocation_command.gd"
)
const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")
const VersionedRngType = preload("res://simulation/rng/versioned_rng.gd")
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807
const MIN_SIGNED_INT: int = -9_223_372_036_854_775_807 - 1
const MONTHS_PER_COMMITTED_QUARTER: int = 3
const TOTAL_BASIS_POINTS: int = 10_000


class RankedContribution:
	extends RefCounted

	var contribution: EffectContributionType
	var original_index: int

	func _init(
		p_contribution: EffectContributionType,
		p_original_index: int
	) -> void:
		contribution = p_contribution
		original_index = p_original_index


## Transforms only committed before/after facts, effects and opponent metadata.
## It never mutates input state or reruns an economic system.
func build(
	before_state: GameStateType,
	tick_result: TickResultType,
	next_signal: OpponentDecisionType,
	quarter_number: int,
	prototype_complete: bool
) -> QuarterReportType:
	if (
		before_state == null
		or tick_result == null
		or not tick_result.is_successful()
		or quarter_number < 1
		or quarter_number > 6
		or prototype_complete != (quarter_number == 6)
	):
		return null
	var after_state: GameStateType = tick_result.get_state_snapshot()
	if after_state == null:
		return null
	if not _states_are_reportable(before_state, after_state):
		return null

	var start_elapsed_months: int = before_state.get_clock().get_elapsed_months()
	var end_elapsed_months: int = after_state.get_clock().get_elapsed_months()
	if (
		start_elapsed_months < 0
		or start_elapsed_months > MAX_SIGNED_INT - MONTHS_PER_COMMITTED_QUARTER
		or end_elapsed_months != start_elapsed_months + MONTHS_PER_COMMITTED_QUARTER
	):
		return null

	var contributions: Array[EffectContributionType] = tick_result.get_contributions()
	var stable_project_id: StringName = before_state.get_project().get_project_id()
	var opponent_is_active: bool = before_state.get_opponent().get_opponent_id() != &""
	if not _contributions_are_valid(contributions, stable_project_id, opponent_is_active):
		return null

	var opponent_facts: Array = _validated_opponent_facts(
		before_state,
		after_state,
		next_signal,
		prototype_complete
	)
	if opponent_facts.is_empty():
		return null

	var metric_keys: Array[StringName] = _metric_keys()
	var before_values: Array[int] = _metric_values(before_state)
	var after_values: Array[int] = _metric_values(after_state)
	if before_values.size() != metric_keys.size() or after_values.size() != metric_keys.size():
		return null

	var displayed_by_metric: Array = []
	for metric_index in metric_keys.size():
		var metric_key: StringName = metric_keys[metric_index]
		if not _can_subtract(after_values[metric_index], before_values[metric_index]):
			return null
		var expected_delta: int = after_values[metric_index] - before_values[metric_index]
		var mapped_sum: int = 0
		var ranked: Array[RankedContribution] = []
		for contribution_index in contributions.size():
			var contribution: EffectContributionType = contributions[contribution_index]
			if not _matches_metric(metric_key, contribution, stable_project_id):
				continue
			if not _can_add(mapped_sum, contribution.get_delta()):
				return null
			mapped_sum += contribution.get_delta()
			ranked.append(RankedContribution.new(contribution, contribution_index))
		if mapped_sum != expected_delta:
			return null
		ranked.sort_custom(_ranked_contribution_less)
		var displayed: Array[EffectContributionType] = []
		var display_count: int = mini(
			ranked.size(),
			QuarterReportType.MAX_DISPLAYED_CONTRIBUTIONS_PER_METRIC
		)
		for display_index in display_count:
			displayed.append(ranked[display_index].contribution)
		displayed_by_metric.append(displayed)

	var report: QuarterReportType = QuarterReportType.new(
		quarter_number,
		start_elapsed_months,
		end_elapsed_months,
		before_values,
		after_values,
		displayed_by_metric,
		contributions,
		opponent_facts[0],
		opponent_facts[1],
		opponent_facts[2],
		opponent_facts[3],
		opponent_facts[4],
		opponent_facts[5],
		opponent_facts[6],
		opponent_facts[7],
		opponent_facts[8],
		opponent_facts[9],
		opponent_facts[10],
		prototype_complete
	)
	return report if report.is_valid() else null


static func _states_are_reportable(
	before_state: GameStateType,
	after_state: GameStateType
) -> bool:
	if (
		before_state.get_clock() == null
		or before_state.get_company() == null
		or before_state.get_project() == null
		or before_state.get_compute() == null
		or before_state.get_market() == null
		or before_state.get_opponent() == null
		or before_state.get_named_rng() == null
		or after_state.get_clock() == null
		or after_state.get_company() == null
		or after_state.get_project() == null
		or after_state.get_compute() == null
		or after_state.get_market() == null
		or after_state.get_opponent() == null
		or after_state.get_named_rng() == null
	):
		return false
	if (
		before_state.get_project().get_project_id() == &""
		or before_state.get_project().get_project_id()
			!= after_state.get_project().get_project_id()
		or before_state.get_opponent().get_opponent_id()
			!= after_state.get_opponent().get_opponent_id()
	):
		return false
	return _metric_state_values_are_valid(before_state) and _metric_state_values_are_valid(
		after_state
	)


static func _metric_state_values_are_valid(state: GameStateType) -> bool:
	return (
		state.get_company().get_monthly_revenue_cents() >= 0
		and state.get_company().get_monthly_operating_cost_cents() >= 0
		and state.get_market().get_consumer_player_share_bps() >= 0
		and state.get_market().get_consumer_player_share_bps() <= TOTAL_BASIS_POINTS
		and state.get_market().get_developer_api_player_share_bps() >= 0
		and state.get_market().get_developer_api_player_share_bps() <= TOTAL_BASIS_POINTS
		and state.get_market().get_consumer_current_market_revenue_cents() >= 0
		and state.get_market().get_developer_api_current_market_revenue_cents() >= 0
		and state.get_compute().get_cumulative_training_compute_unit_months() >= 0
		and state.get_compute().get_cumulative_served_inference_compute_unit_months() >= 0
		and state.get_compute().get_cumulative_unmet_inference_compute_unit_months() >= 0
	)


static func _validated_opponent_facts(
	before_state: GameStateType,
	after_state: GameStateType,
	next_signal: OpponentDecisionType,
	prototype_complete: bool
) -> Array:
	var before_opponent: OpponentStateType = before_state.get_opponent()
	var after_opponent: OpponentStateType = after_state.get_opponent()
	var opponent_id: StringName = after_opponent.get_opponent_id()
	if opponent_id == &"":
		if (
			next_signal != null
			or not _inactive_opponent_is_canonical(before_state)
			or not _inactive_opponent_is_canonical(after_state)
		):
			return []
		return [&"", &"", 0, &"", 0, 0, 0, false, &"", 0, &""]

	if (
		opponent_id != before_opponent.get_opponent_id()
		or not before_state.get_named_rng().is_valid_active_version_one()
		or not after_state.get_named_rng().is_valid_active_version_one()
		or not _committed_metadata_is_valid(after_opponent)
		or not _named_stream_identity_is_preserved(before_state, after_state)
	):
		return []
	if prototype_complete:
		if next_signal != null:
			return []
		return [
			opponent_id,
			after_opponent.get_last_candidate_key(),
			after_opponent.get_last_training_units_per_month(),
			after_opponent.get_last_reason_key(),
			after_opponent.get_last_base_utility_points(),
			after_opponent.get_last_noise_points(),
			after_opponent.get_last_total_utility_points(),
			false,
			&"",
			0,
			&"",
		]
	if not _next_signal_is_valid(after_state, next_signal):
		return []
	var next_command: SetComputeAllocationCommandType = next_signal.get_command()
	return [
		opponent_id,
		after_opponent.get_last_candidate_key(),
		after_opponent.get_last_training_units_per_month(),
		after_opponent.get_last_reason_key(),
		after_opponent.get_last_base_utility_points(),
		after_opponent.get_last_noise_points(),
		after_opponent.get_last_total_utility_points(),
		true,
		next_signal.get_candidate_key(),
		next_command.get_training_units_per_month(),
		next_signal.get_reason_key(),
	]


static func _committed_metadata_is_valid(opponent: OpponentStateType) -> bool:
	if (
		opponent.get_last_candidate_key() == &""
		or opponent.get_last_reason_key() == &""
		or opponent.get_last_training_units_per_month() < 0
		or opponent.get_last_training_units_per_month()
			> opponent.get_compute().get_allocatable_capacity_units_per_month()
		or opponent.get_last_base_utility_points() < 0
		or opponent.get_last_noise_points() < 0
		or opponent.get_last_noise_points() >= VersionedRngType.NOISE_UPPER_BOUND
		or opponent.get_last_total_utility_points() < 0
		or opponent.get_last_base_utility_points()
			> MAX_SIGNED_INT - opponent.get_last_noise_points()
	):
		return false
	return (
		opponent.get_last_total_utility_points()
		== opponent.get_last_base_utility_points() + opponent.get_last_noise_points()
	)


static func _next_signal_is_valid(
	after_state: GameStateType,
	next_signal: OpponentDecisionType
) -> bool:
	if next_signal == null or not next_signal.is_successful():
		return false
	if next_signal.get_candidate_key() == &"" or next_signal.get_reason_key() == &"":
		return false
	var next_command: SetComputeAllocationCommandType = next_signal.get_command()
	if next_command == null or next_command.get_script() != SetComputeAllocationCommandType:
		return false
	var next_training: int = next_command.get_training_units_per_month()
	if (
		next_training < 0
		or next_training
			> after_state.get_opponent().get_compute().get_allocatable_capacity_units_per_month()
	):
		return false
	var proposed_rng = next_signal.get_proposed_rng_state()
	var committed_rng = after_state.get_named_rng()
	return (
		proposed_rng != null
		and proposed_rng.is_valid_active_version_one()
		and proposed_rng.get_master_seed() == committed_rng.get_master_seed()
		and proposed_rng.get_algorithm_version() == committed_rng.get_algorithm_version()
		and proposed_rng.get_events_stream_state() == committed_rng.get_events_stream_state()
		and proposed_rng.get_market_stream_state() == committed_rng.get_market_stream_state()
	)


static func _named_stream_identity_is_preserved(
	before_state: GameStateType,
	after_state: GameStateType
) -> bool:
	var before_rng = before_state.get_named_rng()
	var after_rng = after_state.get_named_rng()
	return (
		before_rng.get_master_seed() == after_rng.get_master_seed()
		and before_rng.get_algorithm_version() == after_rng.get_algorithm_version()
		and before_rng.get_events_stream_state() == after_rng.get_events_stream_state()
		and before_rng.get_market_stream_state() == after_rng.get_market_stream_state()
	)


static func _inactive_opponent_is_canonical(state: GameStateType) -> bool:
	var opponent: OpponentStateType = state.get_opponent()
	var compute = opponent.get_compute()
	return (
		opponent.get_opponent_id() == &""
		and compute != null
		and compute.get_total_units_per_month() == 0
		and compute.get_reserve_units_per_month() == 0
		and compute.get_inference_workload_units_per_month() == 0
		and compute.get_training_allocation_units_per_month() == 0
		and compute.get_cumulative_training_compute_unit_months() == 0
		and compute.get_cumulative_served_inference_compute_unit_months() == 0
		and compute.get_cumulative_unmet_inference_compute_unit_months() == 0
		and opponent.get_last_candidate_key() == &""
		and opponent.get_last_training_units_per_month() == 0
		and opponent.get_last_reason_key() == &""
		and opponent.get_last_base_utility_points() == 0
		and opponent.get_last_noise_points() == 0
		and opponent.get_last_total_utility_points() == 0
		and state.get_named_rng().is_canonical_inactive()
		and state.get_market().get_consumer_opponent_pressure_bps_per_served_unit() == 0
		and state.get_market()
			.get_developer_api_opponent_pressure_bps_per_served_unit() == 0
	)


static func _metric_keys() -> Array[StringName]:
	return [
		QuarterReportType.METRIC_CASH_CENTS,
		QuarterReportType.METRIC_COMPANY_MONTHLY_REVENUE_CENTS,
		QuarterReportType.METRIC_CONSUMER_PLAYER_SHARE_BPS,
		QuarterReportType.METRIC_CONSUMER_MONTHLY_REVENUE_CENTS,
		QuarterReportType.METRIC_DEVELOPER_API_PLAYER_SHARE_BPS,
		QuarterReportType.METRIC_DEVELOPER_API_MONTHLY_REVENUE_CENTS,
		QuarterReportType.METRIC_PLAYER_TRAINING_COMPUTE_UNIT_MONTHS,
		QuarterReportType.METRIC_PLAYER_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS,
		QuarterReportType.METRIC_PLAYER_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS,
	]


static func _metric_values(state: GameStateType) -> Array[int]:
	return [
		state.get_company().get_cash_cents(),
		state.get_company().get_monthly_revenue_cents(),
		state.get_market().get_consumer_player_share_bps(),
		state.get_market().get_consumer_current_market_revenue_cents(),
		state.get_market().get_developer_api_player_share_bps(),
		state.get_market().get_developer_api_current_market_revenue_cents(),
		state.get_compute().get_cumulative_training_compute_unit_months(),
		state.get_compute().get_cumulative_served_inference_compute_unit_months(),
		state.get_compute().get_cumulative_unmet_inference_compute_unit_months(),
	]


static func _matches_metric(
	metric_key: StringName,
	contribution: EffectContributionType,
	stable_project_id: StringName
) -> bool:
	var source: StringName = contribution.get_source_key()
	var reason: StringName = contribution.get_reason_key()
	var subject: StringName = contribution.get_subject_key()
	var metric: StringName = contribution.get_metric_key()
	var unit: int = contribution.get_unit()
	match metric_key:
		QuarterReportType.METRIC_CASH_CENTS:
			return (
				(
					source == EffectContributionType.SOURCE_FINANCE
					and subject == EffectContributionType.SUBJECT_COMPANY
					and metric == EffectContributionType.METRIC_CASH_CENTS
					and unit == EffectContributionType.Unit.CENTS
					and (
						reason == EffectContributionType.REASON_MONTHLY_REVENUE
						or reason == EffectContributionType.REASON_MONTHLY_OPERATING_COST
					)
				)
				or (
					source == EffectContributionType.SOURCE_PROJECT
					and reason == EffectContributionType.REASON_PROJECT_MONTHLY_COST
					and subject == stable_project_id
					and metric == EffectContributionType.METRIC_CASH_CENTS
					and unit == EffectContributionType.Unit.CENTS
				)
			)
		QuarterReportType.METRIC_COMPANY_MONTHLY_REVENUE_CENTS:
			return (
				(
					source == EffectContributionType.SOURCE_PROJECT
					and reason == EffectContributionType.REASON_PROJECT_COMPLETION_REVENUE
					and subject == stable_project_id
					and metric == EffectContributionType.METRIC_MONTHLY_REVENUE_CENTS
					and unit == EffectContributionType.Unit.CENTS
				)
				or _is_market_revenue_contribution(contribution)
			)
		QuarterReportType.METRIC_CONSUMER_PLAYER_SHARE_BPS:
			return _is_market_share_contribution(
				contribution,
				EffectContributionType.SUBJECT_CONSUMER
			)
		QuarterReportType.METRIC_CONSUMER_MONTHLY_REVENUE_CENTS:
			return (
				_is_market_revenue_contribution(contribution)
				and subject == EffectContributionType.SUBJECT_CONSUMER
			)
		QuarterReportType.METRIC_DEVELOPER_API_PLAYER_SHARE_BPS:
			return _is_market_share_contribution(
				contribution,
				EffectContributionType.SUBJECT_DEVELOPER_API
			)
		QuarterReportType.METRIC_DEVELOPER_API_MONTHLY_REVENUE_CENTS:
			return (
				_is_market_revenue_contribution(contribution)
				and subject == EffectContributionType.SUBJECT_DEVELOPER_API
			)
		QuarterReportType.METRIC_PLAYER_TRAINING_COMPUTE_UNIT_MONTHS:
			return _is_player_compute_contribution(
				contribution,
				EffectContributionType.REASON_TRAINING_WORK,
				EffectContributionType.METRIC_CUMULATIVE_TRAINING_COMPUTE_UNIT_MONTHS
			)
		QuarterReportType.METRIC_PLAYER_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS:
			return _is_player_compute_contribution(
				contribution,
				EffectContributionType.REASON_INFERENCE_SERVED,
				EffectContributionType.METRIC_CUMULATIVE_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS
			)
		QuarterReportType.METRIC_PLAYER_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS:
			return _is_player_compute_contribution(
				contribution,
				EffectContributionType.REASON_INFERENCE_UNMET,
				EffectContributionType.METRIC_CUMULATIVE_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS
			)
	return false


static func _is_market_share_contribution(
	contribution: EffectContributionType,
	expected_subject: StringName
) -> bool:
	return (
		contribution.get_source_key() == EffectContributionType.SOURCE_MARKET
		and contribution.get_subject_key() == expected_subject
		and contribution.get_metric_key() == EffectContributionType.METRIC_PLAYER_SHARE_BPS
		and contribution.get_unit() == EffectContributionType.Unit.BASIS_POINTS
		and (
			contribution.get_reason_key() == EffectContributionType.REASON_MARKET_SHARE_CHANGE
			or contribution.get_reason_key()
				== EffectContributionType.REASON_OPPONENT_MARKET_PRESSURE
		)
	)


static func _is_market_revenue_contribution(
	contribution: EffectContributionType
) -> bool:
	return (
		contribution.get_source_key() == EffectContributionType.SOURCE_MARKET
		and contribution.get_reason_key()
			== EffectContributionType.REASON_MARKET_REVENUE_CHANGE
		and (
			contribution.get_subject_key() == EffectContributionType.SUBJECT_CONSUMER
			or contribution.get_subject_key() == EffectContributionType.SUBJECT_DEVELOPER_API
		)
		and contribution.get_metric_key()
			== EffectContributionType.METRIC_MARKET_MONTHLY_REVENUE_CENTS
		and contribution.get_unit() == EffectContributionType.Unit.CENTS
	)


static func _is_player_compute_contribution(
	contribution: EffectContributionType,
	expected_reason: StringName,
	expected_metric: StringName
) -> bool:
	return (
		contribution.get_source_key() == EffectContributionType.SOURCE_COMPUTE
		and contribution.get_reason_key() == expected_reason
		and contribution.get_subject_key() == EffectContributionType.SUBJECT_COMPANY
		and contribution.get_metric_key() == expected_metric
		and contribution.get_unit() == EffectContributionType.Unit.COMPUTE_UNIT_MONTHS
	)


static func _contributions_are_valid(
	contributions: Array[EffectContributionType],
	stable_project_id: StringName,
	opponent_is_active: bool
) -> bool:
	for contribution in contributions:
		if (
			contribution == null
			or contribution.get_source_key() == &""
			or contribution.get_reason_key() == &""
			or contribution.get_subject_key() == &""
			or contribution.get_metric_key() == &""
			or contribution.get_unit() < EffectContributionType.Unit.CENTS
			or contribution.get_unit() > EffectContributionType.Unit.BASIS_POINTS
			or contribution.get_delta() == 0
			or contribution.get_delta() == MIN_SIGNED_INT
			or not _is_known_contribution(
				contribution,
				stable_project_id,
				opponent_is_active
			)
		):
			return false
	return true


static func _is_known_contribution(
	contribution: EffectContributionType,
	stable_project_id: StringName,
	opponent_is_active: bool
) -> bool:
	var source: StringName = contribution.get_source_key()
	var reason: StringName = contribution.get_reason_key()
	var subject: StringName = contribution.get_subject_key()
	var metric: StringName = contribution.get_metric_key()
	var unit: int = contribution.get_unit()
	var delta: int = contribution.get_delta()
	match source:
		EffectContributionType.SOURCE_FINANCE:
			if (
				subject != EffectContributionType.SUBJECT_COMPANY
				or metric != EffectContributionType.METRIC_CASH_CENTS
				or unit != EffectContributionType.Unit.CENTS
			):
				return false
			return (
				(reason == EffectContributionType.REASON_MONTHLY_REVENUE and delta > 0)
				or (
					reason == EffectContributionType.REASON_MONTHLY_OPERATING_COST
					and delta < 0
				)
			)
		EffectContributionType.SOURCE_PROJECT:
			if subject != stable_project_id:
				return false
			match reason:
				EffectContributionType.REASON_PROJECT_MONTHLY_COST:
					return (
						metric == EffectContributionType.METRIC_CASH_CENTS
						and unit == EffectContributionType.Unit.CENTS
						and delta < 0
					)
				EffectContributionType.REASON_PROJECT_PROGRESS:
					return (
						metric == EffectContributionType.METRIC_PROJECT_PROGRESS_MONTHS
						and unit == EffectContributionType.Unit.MONTHS
						and delta == 1
					)
				EffectContributionType.REASON_PROJECT_COMPLETION_REVENUE:
					return (
						metric == EffectContributionType.METRIC_MONTHLY_REVENUE_CENTS
						and unit == EffectContributionType.Unit.CENTS
						and delta > 0
					)
		EffectContributionType.SOURCE_COMPUTE:
			if (
				subject != EffectContributionType.SUBJECT_COMPANY
				and (
					not opponent_is_active
					or subject != EffectContributionType.SUBJECT_NORTHSTAR_LABS
				)
			):
				return false
			if unit != EffectContributionType.Unit.COMPUTE_UNIT_MONTHS or delta <= 0:
				return false
			match reason:
				EffectContributionType.REASON_TRAINING_WORK:
					return metric == (
						EffectContributionType.METRIC_CUMULATIVE_TRAINING_COMPUTE_UNIT_MONTHS
					)
				EffectContributionType.REASON_INFERENCE_SERVED:
					return metric == (
						EffectContributionType
							.METRIC_CUMULATIVE_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS
					)
				EffectContributionType.REASON_INFERENCE_UNMET:
					return metric == (
						EffectContributionType
							.METRIC_CUMULATIVE_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS
					)
		EffectContributionType.SOURCE_MARKET:
			if (
				subject != EffectContributionType.SUBJECT_CONSUMER
				and subject != EffectContributionType.SUBJECT_DEVELOPER_API
			):
				return false
			match reason:
				EffectContributionType.REASON_MARKET_SERVED:
					return (
						metric
							== EffectContributionType
								.METRIC_CUMULATIVE_MARKET_SERVED_COMPUTE_UNIT_MONTHS
						and unit == EffectContributionType.Unit.COMPUTE_UNIT_MONTHS
						and delta > 0
					)
				EffectContributionType.REASON_MARKET_UNMET:
					return (
						metric
							== EffectContributionType
								.METRIC_CUMULATIVE_MARKET_UNMET_COMPUTE_UNIT_MONTHS
						and unit == EffectContributionType.Unit.COMPUTE_UNIT_MONTHS
						and delta > 0
					)
				EffectContributionType.REASON_MARKET_SHARE_CHANGE:
					return (
						metric == EffectContributionType.METRIC_PLAYER_SHARE_BPS
						and unit == EffectContributionType.Unit.BASIS_POINTS
					)
				EffectContributionType.REASON_OPPONENT_MARKET_PRESSURE:
					return (
						opponent_is_active
						and metric == EffectContributionType.METRIC_PLAYER_SHARE_BPS
						and unit == EffectContributionType.Unit.BASIS_POINTS
						and delta < 0
					)
				EffectContributionType.REASON_MARKET_REVENUE_CHANGE:
					return (
						metric
							== EffectContributionType.METRIC_MARKET_MONTHLY_REVENUE_CENTS
						and unit == EffectContributionType.Unit.CENTS
					)
	return false


static func _ranked_contribution_less(
	first: RankedContribution,
	second: RankedContribution
) -> bool:
	var first_magnitude: int = _safe_magnitude(first.contribution.get_delta())
	var second_magnitude: int = _safe_magnitude(second.contribution.get_delta())
	if first_magnitude != second_magnitude:
		return first_magnitude > second_magnitude
	if first.original_index != second.original_index:
		return first.original_index < second.original_index
	var first_keys: Array[String] = _sortable_keys(first.contribution)
	var second_keys: Array[String] = _sortable_keys(second.contribution)
	for key_index in first_keys.size():
		if first_keys[key_index] != second_keys[key_index]:
			return first_keys[key_index] < second_keys[key_index]
	return false


static func _sortable_keys(contribution: EffectContributionType) -> Array[String]:
	return [
		String(contribution.get_source_key()),
		String(contribution.get_reason_key()),
		String(contribution.get_subject_key()),
		String(contribution.get_metric_key()),
	]


static func _safe_magnitude(value: int) -> int:
	return -value if value < 0 else value


static func _can_add(value: int, delta: int) -> bool:
	if delta > 0:
		return value <= MAX_SIGNED_INT - delta
	if delta < 0:
		return value >= MIN_SIGNED_INT - delta
	return true


static func _can_subtract(value: int, subtrahend: int) -> bool:
	if subtrahend > 0:
		return value >= MIN_SIGNED_INT + subtrahend
	if subtrahend < 0:
		return value <= MAX_SIGNED_INT + subtrahend
	return true
