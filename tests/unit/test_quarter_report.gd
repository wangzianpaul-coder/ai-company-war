extends RefCounted


const CompanyStateType = preload("res://simulation/state/company_state.gd")
const ProjectStateType = preload("res://simulation/state/project_state.gd")
const ComputeStateType = preload("res://simulation/state/compute_state.gd")
const MarketStateType = preload("res://simulation/state/market_state.gd")
const OpponentStateType = preload("res://simulation/state/opponent_state.gd")
const NamedRngStateType = preload("res://simulation/rng/named_rng_state.gd")
const GameStateType = preload("res://simulation/state/game_state.gd")
const OpponentPlanningSnapshotType = preload(
	"res://simulation/ai/opponent_planning_snapshot.gd"
)
const OpponentPersonalityType = preload("res://simulation/ai/opponent_personality.gd")
const OpponentDecisionType = preload("res://simulation/ai/opponent_decision.gd")
const AiSystemType = preload("res://simulation/systems/ai_system.gd")
const SimulationEngineType = preload("res://simulation/engine/simulation_engine.gd")
const TickResultType = preload("res://simulation/engine/tick_result.gd")
const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")
const QuarterReportType = preload("res://simulation/reports/quarter_report.gd")
const QuarterReportBuilderType = preload(
	"res://simulation/reports/quarter_report_builder.gd"
)
const MIN_SIGNED_INT: int = -9_223_372_036_854_775_807 - 1


class Fixture:
	extends RefCounted

	var before_state: GameStateType
	var tick_result: TickResultType
	var next_signal: OpponentDecisionType


static func run(report: Callable) -> void:
	_report(
		report,
		_test_report_owns_every_input_and_returned_copy(),
		"TP-023 quarter report owns immutable committed facts"
	)
	_report(
		report,
		_test_every_metric_reconciles_to_the_full_ordered_effect_set(),
		"TP-023 quarter report reconciles metric changes to ordered contributions"
	)
	_report(
		report,
		_test_top_three_and_signal_boundaries_are_deterministic(),
		"TP-023 quarter report selects deterministic top-three reasons and known risks"
	)


static func _test_report_owns_every_input_and_returned_copy() -> bool:
	var fixture: Fixture = _create_fixture(0)
	if fixture == null:
		return false
	var source_contributions: Array[EffectContributionType] = (
		fixture.tick_result.get_contributions()
	)
	var quarter_report: QuarterReportType = QuarterReportBuilderType.new().build(
		fixture.before_state,
		fixture.tick_result,
		fixture.next_signal,
		1,
		false
	)
	if quarter_report == null or not quarter_report.is_valid():
		return false

	var first_full_copy: Array[EffectContributionType] = quarter_report.get_contributions()
	var second_full_copy: Array[EffectContributionType] = quarter_report.get_contributions()
	var cash_display: Array[EffectContributionType] = (
		quarter_report.get_displayed_contributions(QuarterReportType.METRIC_CASH_CENTS)
	)
	var metric_keys: Array[StringName] = quarter_report.get_metric_keys()
	var report_copy: QuarterReportType = quarter_report.copy()
	if (
		first_full_copy.size() != 52
		or second_full_copy.size() != 52
		or cash_display.size() != 3
		or metric_keys.size() != 9
		or first_full_copy[0] == source_contributions[0]
		or first_full_copy[0] == second_full_copy[0]
		or report_copy == null
		or report_copy == quarter_report
		or report_copy.get_contributions()[0] == first_full_copy[0]
		or report_copy.get_quarter_number() != 1
		or report_copy.get_start_elapsed_months() != 0
		or report_copy.get_end_elapsed_months() != 3
	):
		return false
	if not _displayed_contribution_copies_are_independent(
		quarter_report,
		report_copy,
		source_contributions
	):
		return false

	first_full_copy.clear()
	second_full_copy.clear()
	cash_display.clear()
	metric_keys.clear()
	return (
		quarter_report.get_contributions().size() == 52
		and quarter_report.get_displayed_contributions(
			QuarterReportType.METRIC_CASH_CENTS
		).size() == 3
		and quarter_report.get_metric_keys().size() == 9
		and quarter_report.get_committed_opponent_id()
			== OpponentStateType.NORTHSTAR_LABS_ID
		and quarter_report.get_committed_candidate_key()
			== OpponentPersonalityType.CANDIDATE_PLAN_70_CLOSE_TRAINING_GAP
		and quarter_report.get_committed_training_units_per_month() == 70
		and quarter_report.get_committed_reason_key()
			== OpponentPersonalityType.REASON_CLOSE_TRAINING_GAP
		and quarter_report.get_committed_base_utility_points() == 680
		and quarter_report.get_committed_noise_points() == 8
		and quarter_report.get_committed_total_utility_points() == 688
	)


static func _test_every_metric_reconciles_to_the_full_ordered_effect_set() -> bool:
	var fixture: Fixture = _create_fixture(0)
	if fixture == null:
		return false
	var builder: QuarterReportBuilderType = QuarterReportBuilderType.new()
	var quarter_report: QuarterReportType = builder.build(
		fixture.before_state,
		fixture.tick_result,
		fixture.next_signal,
		1,
		false
	)
	if quarter_report == null:
		return false
	var exact_goldens: bool = (
		_metric_matches(quarter_report, QuarterReportType.METRIC_CASH_CENTS, 1_000_000, 1_071_130)
		and _metric_matches(
			quarter_report,
			QuarterReportType.METRIC_COMPANY_MONTHLY_REVENUE_CENTS,
			120_000,
			146_130
		)
		and _metric_matches(
			quarter_report,
			QuarterReportType.METRIC_CONSUMER_PLAYER_SHARE_BPS,
			3_000,
			3_018
		)
		and _metric_matches(
			quarter_report,
			QuarterReportType.METRIC_CONSUMER_MONTHLY_REVENUE_CENTS,
			30_000,
			30_180
		)
		and _metric_matches(
			quarter_report,
			QuarterReportType.METRIC_DEVELOPER_API_PLAYER_SHARE_BPS,
			2_000,
			1_910
		)
		and _metric_matches(
			quarter_report,
			QuarterReportType.METRIC_DEVELOPER_API_MONTHLY_REVENUE_CENTS,
			90_000,
			85_950
		)
		and _metric_matches(
			quarter_report,
			QuarterReportType.METRIC_PLAYER_TRAINING_COMPUTE_UNIT_MONTHS,
			0,
			120
		)
		and _metric_matches(
			quarter_report,
			QuarterReportType.METRIC_PLAYER_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS,
			0,
			150
		)
		and _metric_matches(
			quarter_report,
			QuarterReportType.METRIC_PLAYER_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS,
			0,
			0
		)
	)
	if not exact_goldens:
		return false

	var training_display: Array[EffectContributionType] = (
		quarter_report.get_displayed_contributions(
			QuarterReportType.METRIC_PLAYER_TRAINING_COMPUTE_UNIT_MONTHS
		)
	)
	if training_display.size() != 3:
		return false
	for contribution in training_display:
		if contribution.get_subject_key() != EffectContributionType.SUBJECT_COMPANY:
			return false

	var tampered_after: GameStateType = fixture.tick_result.get_state_snapshot()
	tampered_after.get_company()._commit_financials(
		tampered_after.get_company().get_cash_cents(),
		tampered_after.get_company().get_monthly_revenue_cents() + 1
	)
	var tampered_result: TickResultType = TickResultType.new(
		tampered_after,
		fixture.tick_result.get_contributions()
	)
	return builder.build(
		fixture.before_state,
		tampered_result,
		fixture.next_signal,
		1,
		false
	) == null


static func _test_top_three_and_signal_boundaries_are_deterministic() -> bool:
	var fixture: Fixture = _create_fixture(0)
	if fixture == null:
		return false
	var builder: QuarterReportBuilderType = QuarterReportBuilderType.new()
	var quarter_report: QuarterReportType = builder.build(
		fixture.before_state,
		fixture.tick_result,
		fixture.next_signal,
		1,
		false
	)
	if quarter_report == null:
		return false
	var cash_display: Array[EffectContributionType] = (
		quarter_report.get_displayed_contributions(QuarterReportType.METRIC_CASH_CENTS)
	)
	var revenue_display: Array[EffectContributionType] = (
		quarter_report.get_displayed_contributions(
			QuarterReportType.METRIC_COMPANY_MONTHLY_REVENUE_CENTS
		)
	)
	if (
		not _deltas_match(cash_display, [147_420, 120_000, 118_710])
		or not _deltas_match(revenue_display, [30_000, -1_350, -1_350])
		or revenue_display[0].get_subject_key() != &"project_alpha"
		or revenue_display[1].get_subject_key()
			!= EffectContributionType.SUBJECT_DEVELOPER_API
		or revenue_display[2].get_subject_key()
			!= EffectContributionType.SUBJECT_DEVELOPER_API
		or revenue_display[1].get_reason_key()
			!= EffectContributionType.REASON_MARKET_REVENUE_CHANGE
		or revenue_display[2].get_reason_key()
			!= EffectContributionType.REASON_MARKET_REVENUE_CHANGE
		or quarter_report.get_all_displayed_reason_keys().size() != 24
		or not quarter_report.has_next_signal()
		or quarter_report.get_next_candidate_key()
			!= OpponentPersonalityType.CANDIDATE_PLAN_40_DEFEND_MARKETS
		or quarter_report.get_next_training_units_per_month() != 40
		or quarter_report.get_next_reason_key()
			!= OpponentPersonalityType.REASON_DEFEND_MARKET_POSITION
		or quarter_report.is_prototype_complete()
	):
		return false

	var final_fixture: Fixture = _create_fixture(15)
	if final_fixture == null:
		return false
	var final_report: QuarterReportType = builder.build(
		final_fixture.before_state,
		final_fixture.tick_result,
		null,
		6,
		true
	)
	if (
		final_report == null
		or final_report.get_start_elapsed_months() != 15
		or final_report.get_end_elapsed_months() != 18
		or final_report.has_next_signal()
		or final_report.get_next_candidate_key() != &""
		or final_report.get_next_training_units_per_month() != 0
		or final_report.get_next_reason_key() != &""
		or not final_report.is_prototype_complete()
		or builder.build(
			final_fixture.before_state,
			final_fixture.tick_result,
			final_fixture.next_signal,
			6,
			true
		) != null
		or builder.build(
			fixture.before_state,
			fixture.tick_result,
			null,
			1,
			false
		) != null
	):
		return false

	return (
		_test_equal_magnitude_ties_follow_original_order()
		and _test_minimum_delta_guard_is_isolated()
	)


static func _test_equal_magnitude_ties_follow_original_order() -> bool:
	var consumer_first: QuarterReportType = _make_equal_magnitude_revenue_case(true)
	var developer_first: QuarterReportType = _make_equal_magnitude_revenue_case(false)
	if consumer_first == null or developer_first == null:
		return false
	var consumer_first_display: Array[EffectContributionType] = (
		consumer_first.get_displayed_contributions(
			QuarterReportType.METRIC_COMPANY_MONTHLY_REVENUE_CENTS
		)
	)
	var developer_first_display: Array[EffectContributionType] = (
		developer_first.get_displayed_contributions(
			QuarterReportType.METRIC_COMPANY_MONTHLY_REVENUE_CENTS
		)
	)
	return (
		_deltas_match(consumer_first_display, [1_000, -1_000])
		and consumer_first_display[0].get_subject_key()
			== EffectContributionType.SUBJECT_CONSUMER
		and consumer_first_display[1].get_subject_key()
			== EffectContributionType.SUBJECT_DEVELOPER_API
		and _deltas_match(developer_first_display, [-1_000, 1_000])
		and developer_first_display[0].get_subject_key()
			== EffectContributionType.SUBJECT_DEVELOPER_API
		and developer_first_display[1].get_subject_key()
			== EffectContributionType.SUBJECT_CONSUMER
	)


static func _make_equal_magnitude_revenue_case(
	consumer_first: bool
) -> QuarterReportType:
	var before_state: GameStateType = _create_revenue_tie_state(1_000, 2_000)
	var after_state: GameStateType = _create_revenue_tie_state(2_000, 1_000)
	if not after_state.get_clock().advance_months(3):
		return null
	var consumer_contribution: EffectContributionType = EffectContributionType.new(
		EffectContributionType.SOURCE_MARKET,
		EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
		EffectContributionType.SUBJECT_CONSUMER,
		EffectContributionType.METRIC_MARKET_MONTHLY_REVENUE_CENTS,
		EffectContributionType.Unit.CENTS,
		1_000
	)
	var developer_contribution: EffectContributionType = EffectContributionType.new(
		EffectContributionType.SOURCE_MARKET,
		EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
		EffectContributionType.SUBJECT_DEVELOPER_API,
		EffectContributionType.METRIC_MARKET_MONTHLY_REVENUE_CENTS,
		EffectContributionType.Unit.CENTS,
		-1_000
	)
	var contributions: Array[EffectContributionType] = []
	if consumer_first:
		contributions.append(consumer_contribution)
		contributions.append(developer_contribution)
	else:
		contributions.append(developer_contribution)
		contributions.append(consumer_contribution)
	return QuarterReportBuilderType.new().build(
		before_state,
		TickResultType.new(after_state, contributions),
		null,
		1,
		false
	)


static func _create_revenue_tie_state(
	consumer_revenue_cents: int,
	developer_revenue_cents: int
) -> GameStateType:
	var market: MarketStateType = MarketStateType.new(
		0,
		0,
		0,
		1_000,
		1_000,
		10_000,
		10_000,
		0,
		0,
		0,
		0,
		0,
		0,
		consumer_revenue_cents,
		developer_revenue_cents,
		0,
		0,
		0,
		0,
		0,
		0
	)
	return GameStateType.new(
		CompanyStateType.new(0, 3_000, 0),
		ProjectStateType.new(&"project_tie_fixture", 3, 0, 0),
		ComputeStateType.new(),
		market
	)


static func _test_minimum_delta_guard_is_isolated() -> bool:
	var safe_extreme_report: QuarterReportType = _make_cash_delta_case(
		MIN_SIGNED_INT + 1
	)
	if safe_extreme_report == null or not safe_extreme_report.is_valid():
		return false
	var cash_display: Array[EffectContributionType] = (
		safe_extreme_report.get_displayed_contributions(
			QuarterReportType.METRIC_CASH_CENTS
		)
	)
	return (
		safe_extreme_report.get_before_value(QuarterReportType.METRIC_CASH_CENTS) == 0
		and safe_extreme_report.get_after_value(QuarterReportType.METRIC_CASH_CENTS)
			== MIN_SIGNED_INT + 1
		and _deltas_match(cash_display, [MIN_SIGNED_INT + 1])
		and _make_cash_delta_case(MIN_SIGNED_INT) == null
	)


static func _make_cash_delta_case(cash_delta_cents: int) -> QuarterReportType:
	var before_state: GameStateType = GameStateType.new(
		CompanyStateType.new(0, 0, 0),
		ProjectStateType.new(&"project_minimum_delta_fixture", 3, 0, 0)
	)
	var after_state: GameStateType = before_state.copy()
	if after_state == null or not after_state.get_clock().advance_months(3):
		return null
	after_state.get_company()._commit_financials(cash_delta_cents, 0)
	var contributions: Array[EffectContributionType] = [
		EffectContributionType.new(
			EffectContributionType.SOURCE_FINANCE,
			EffectContributionType.REASON_MONTHLY_OPERATING_COST,
			EffectContributionType.SUBJECT_COMPANY,
			EffectContributionType.METRIC_CASH_CENTS,
			EffectContributionType.Unit.CENTS,
			cash_delta_cents
		),
	]
	return QuarterReportBuilderType.new().build(
		before_state,
		TickResultType.new(after_state, contributions),
		null,
		1,
		false
	)


static func _create_fixture(start_elapsed_months: int) -> Fixture:
	var initial_state: GameStateType = _create_canonical_state()
	if initial_state == null or not initial_state.get_clock().advance_months(
		start_elapsed_months
	):
		return null
	var personality: OpponentPersonalityType = _create_personality()
	var engine: SimulationEngineType = SimulationEngineType.new()
	var start_result: TickResultType = engine.start_project(initial_state)
	if start_result == null or not start_result.is_successful():
		return null
	var before_state: GameStateType = start_result.get_state_snapshot()
	var planning_snapshot: OpponentPlanningSnapshotType = _snapshot_for(before_state)
	var tick_result: TickResultType = engine.advance_quarter(
		before_state,
		planning_snapshot,
		personality
	)
	if tick_result == null or not tick_result.is_successful():
		return null
	var after_state: GameStateType = tick_result.get_state_snapshot()
	var next_signal: OpponentDecisionType = AiSystemType.new().decide(
		_snapshot_for(after_state),
		after_state.get_opponent(),
		personality,
		after_state.get_named_rng()
	)
	if next_signal == null or not next_signal.is_successful():
		return null
	var fixture: Fixture = Fixture.new()
	fixture.before_state = before_state
	fixture.tick_result = tick_result
	fixture.next_signal = next_signal
	return fixture


static func _create_canonical_state() -> GameStateType:
	var market: MarketStateType = MarketStateType.new(
		30,
		20,
		6_000,
		3_000,
		2_000,
		100_000,
		450_000,
		30,
		10,
		10,
		25,
		30,
		20,
		30_000,
		90_000,
		0,
		0,
		0,
		0,
		2,
		5
	)
	var opponent: OpponentStateType = OpponentStateType.new(
		OpponentStateType.NORTHSTAR_LABS_ID,
		ComputeStateType.new(100, 10, 50, 40)
	)
	return GameStateType.new(
		CompanyStateType.new(1_000_000, 120_000, 80_000),
		ProjectStateType.new(&"project_alpha", 3, 25_000, 30_000),
		ComputeStateType.new(100, 10, 50, 40),
		market,
		opponent,
		NamedRngStateType.create_fresh_version_one(7)
	)


static func _create_personality() -> OpponentPersonalityType:
	var candidates: Array[OpponentPersonalityType.Candidate] = [
		OpponentPersonalityType.Candidate.new(
			OpponentPersonalityType.CANDIDATE_PLAN_40_DEFEND_MARKETS,
			40,
			OpponentPersonalityType.REASON_DEFEND_MARKET_POSITION,
			OpponentPersonalityType.UTILITY_RULE_DEFEND_MARKETS
		),
		OpponentPersonalityType.Candidate.new(
			OpponentPersonalityType.CANDIDATE_PLAN_70_CLOSE_TRAINING_GAP,
			70,
			OpponentPersonalityType.REASON_CLOSE_TRAINING_GAP,
			OpponentPersonalityType.UTILITY_RULE_CLOSE_TRAINING_GAP
		),
	]
	return OpponentPersonalityType.new(
		OpponentStateType.NORTHSTAR_LABS_ID,
		"Northstar Labs",
		candidates,
		500,
		100,
		500,
		180
	)


static func _snapshot_for(state: GameStateType) -> OpponentPlanningSnapshotType:
	return OpponentPlanningSnapshotType.new(
		state.get_clock().get_elapsed_months(),
		state.get_market().get_consumer_player_share_bps(),
		state.get_market().get_developer_api_player_share_bps()
	)


static func _displayed_contribution_copies_are_independent(
	original_report: QuarterReportType,
	copied_report: QuarterReportType,
	source_contributions: Array[EffectContributionType]
) -> bool:
	var original_storage_value: Variant = original_report.get(
		&"_displayed_contributions_by_metric"
	)
	var copied_storage_value: Variant = copied_report.get(
		&"_displayed_contributions_by_metric"
	)
	if (
		typeof(original_storage_value) != TYPE_ARRAY
		or typeof(copied_storage_value) != TYPE_ARRAY
	):
		return false
	var original_storage: Array = original_storage_value
	var copied_storage: Array = copied_storage_value
	var metric_keys: Array[StringName] = original_report.get_metric_keys()
	if (
		original_storage.size() != metric_keys.size()
		or copied_storage.size() != metric_keys.size()
	):
		return false
	for metric_index in metric_keys.size():
		if (
			typeof(original_storage[metric_index]) != TYPE_ARRAY
			or typeof(copied_storage[metric_index]) != TYPE_ARRAY
		):
			return false
		var original_metric: Array = original_storage[metric_index]
		var copied_metric: Array = copied_storage[metric_index]
		var first_getter: Array[EffectContributionType] = (
			original_report.get_displayed_contributions(metric_keys[metric_index])
		)
		var second_getter: Array[EffectContributionType] = (
			original_report.get_displayed_contributions(metric_keys[metric_index])
		)
		var copied_getter: Array[EffectContributionType] = (
			copied_report.get_displayed_contributions(metric_keys[metric_index])
		)
		if (
			copied_metric.size() != original_metric.size()
			or first_getter.size() != original_metric.size()
			or second_getter.size() != original_metric.size()
			or copied_getter.size() != original_metric.size()
		):
			return false
		for display_index in original_metric.size():
			var original_stored: EffectContributionType = original_metric[display_index]
			var copied_stored: EffectContributionType = copied_metric[display_index]
			var first_returned: EffectContributionType = first_getter[display_index]
			var second_returned: EffectContributionType = second_getter[display_index]
			var copied_returned: EffectContributionType = copied_getter[display_index]
			if (
				original_stored == null
				or copied_stored == null
				or first_returned == null
				or second_returned == null
				or copied_returned == null
				or _contains_contribution_identity(source_contributions, original_stored)
				or _contains_contribution_identity(source_contributions, copied_stored)
				or _contains_contribution_identity(source_contributions, first_returned)
				or _contains_contribution_identity(source_contributions, second_returned)
				or _contains_contribution_identity(source_contributions, copied_returned)
				or not _contains_equal_contribution(source_contributions, original_stored)
				or original_stored == copied_stored
				or original_stored == first_returned
				or original_stored == second_returned
				or copied_stored == copied_returned
				or first_returned == second_returned
				or first_returned == copied_returned
				or not _contribution_facts_equal(original_stored, copied_stored)
				or not _contribution_facts_equal(original_stored, first_returned)
				or not _contribution_facts_equal(original_stored, second_returned)
				or not _contribution_facts_equal(original_stored, copied_returned)
			):
				return false
	return true


static func _contains_contribution_identity(
	contributions: Array[EffectContributionType],
	target: EffectContributionType
) -> bool:
	for contribution in contributions:
		if contribution == target:
			return true
	return false


static func _contains_equal_contribution(
	contributions: Array[EffectContributionType],
	target: EffectContributionType
) -> bool:
	for contribution in contributions:
		if _contribution_facts_equal(contribution, target):
			return true
	return false


static func _contribution_facts_equal(
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


static func _metric_matches(
	quarter_report: QuarterReportType,
	metric_key: StringName,
	expected_before: int,
	expected_after: int
) -> bool:
	return (
		quarter_report.get_before_value(metric_key) == expected_before
		and quarter_report.get_after_value(metric_key) == expected_after
	)


static func _deltas_match(
	contributions: Array[EffectContributionType],
	expected_deltas: Array
) -> bool:
	if contributions.size() != expected_deltas.size():
		return false
	for contribution_index in contributions.size():
		if contributions[contribution_index].get_delta() != expected_deltas[contribution_index]:
			return false
	return true


static func _report(report: Callable, condition: bool, description: String) -> void:
	report.call(condition, description)
