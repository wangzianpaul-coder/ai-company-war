extends RefCounted


const GameCommandType = preload("res://simulation/commands/game_command.gd")
const StartProjectCommandType = preload("res://simulation/commands/start_project_command.gd")
const AdvanceQuarterCommandType = preload("res://simulation/commands/advance_quarter_command.gd")
const SetComputeAllocationCommandType = preload(
	"res://simulation/commands/set_compute_allocation_command.gd"
)
const SimulationEngineType = preload("res://simulation/engine/simulation_engine.gd")
const TickResultType = preload("res://simulation/engine/tick_result.gd")
const GameStateType = preload("res://simulation/state/game_state.gd")
const CompanyStateType = preload("res://simulation/state/company_state.gd")
const ProjectStateType = preload("res://simulation/state/project_state.gd")
const ComputeStateType = preload("res://simulation/state/compute_state.gd")
const MarketStateType = preload("res://simulation/state/market_state.gd")
const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")
const EffectBatchResultType = preload("res://simulation/events/effect_batch_result.gd")
const MarketSystemType = preload("res://simulation/systems/market_system.gd")
const GameSessionType = preload("res://application/game_session.gd")
const DashboardViewModelType = preload("res://application/view_models/dashboard_view_model.gd")
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807
const PROJECT_ID: StringName = &"project_alpha"


class UnknownGameCommand:
	extends GameCommandType


class DerivedSetComputeAllocationCommand:
	extends SetComputeAllocationCommandType

	func _init(p_training_units_per_month: int) -> void:
		super(p_training_units_per_month)


class CommitObserver:
	extends RefCounted

	var count: int = 0
	var every_signal_saw_committed_values: bool = true
	var _session

	func _init(p_session) -> void:
		_session = p_session

	func capture(view_model: DashboardViewModelType) -> void:
		count += 1
		var snapshot: GameStateType = _session.get_state_snapshot()
		var committed_before_signal: bool = (
			snapshot != null
			and _session.get_current_view_model() == view_model
		)
		if count == 1:
			committed_before_signal = (
				committed_before_signal
				and snapshot.get_compute().get_training_allocation_units_per_month() == 70
				and snapshot.get_project().get_lifecycle()
					== ProjectStateType.Lifecycle.NOT_STARTED
				and _session.get_last_committed_contributions().is_empty()
			)
		elif count == 2:
			committed_before_signal = (
				committed_before_signal
				and snapshot.get_compute().get_training_allocation_units_per_month() == 70
				and snapshot.get_project().get_lifecycle() == ProjectStateType.Lifecycle.ACTIVE
				and _session.get_last_committed_contributions().is_empty()
			)
		elif count == 3:
			committed_before_signal = (
				committed_before_signal
				and snapshot.get_clock().get_elapsed_months() == 3
				and snapshot.get_company().get_cash_cents() == 912_640
				and snapshot.get_market().get_consumer_player_share_bps() == 2_460
				and snapshot.get_market().get_developer_api_player_share_bps() == 1_100
				and _session.get_last_committed_contributions().size() == 46
				and view_model.get_consumer_market_text()
					== "Consumer: served 36/90, share -540 → 2,460 bps, revenue -20,160 → 9,840"
				and view_model.get_developer_api_market_text()
					== "Developer/API: served 24/60, share -900 → 1,100 bps, revenue -70,200 → 19,800"
			)
		else:
			committed_before_signal = false
		every_signal_saw_committed_values = (
			every_signal_saw_committed_values and committed_before_signal
		)


static func run(report: Callable) -> void:
	var quarter_exact: bool = _test_golden_quarters_and_order()
	var rollback_exact: bool = _test_failure_positions()
	_report(
		report,
		quarter_exact and rollback_exact,
		"TP-021 market quarter preserves ordered effects and rollback"
	)
	_report(
		report,
		rollback_exact,
		"TP-021 Market failures at months 1, 2, and 3 discard the whole quarter"
	)
	var session_exact: bool = _test_game_session_boundary()
	var deterministic_exact: bool = _test_deterministic_sessions()
	_report(
		report,
		session_exact and deterministic_exact,
		"TP-021 GameSession publishes only committed market outcomes"
	)
	_report(
		report,
		deterministic_exact,
		"TP-021 default and constrained market sessions remain deterministic"
	)


static func report_dashboard_scene(report: Callable, condition: bool) -> void:
	_report(
		report,
		condition,
		"TP-021 dashboard explains Consumer and Developer/API outcomes"
	)


static func report_dashboard_layout(report: Callable, condition: bool) -> void:
	_report(
		report,
		condition,
		"TP-021 dashboard fits 1280x720 and 1920x1080"
	)


static func _test_golden_quarters_and_order() -> bool:
	var engine: SimulationEngineType = SimulationEngineType.new()
	var default_result: TickResultType = engine.advance_quarter(_create_active_state(40))
	var constrained_result: TickResultType = engine.advance_quarter(_create_active_state(70))
	if (
		default_result == null
		or not default_result.is_successful()
		or constrained_result == null
		or not constrained_result.is_successful()
	):
		return false

	var default_state: GameStateType = default_result.get_state_snapshot()
	var constrained_state: GameStateType = constrained_result.get_state_snapshot()
	var default_trace: Array[EffectContributionType] = default_result.get_contributions()
	var constrained_trace: Array[EffectContributionType] = (
		constrained_result.get_contributions()
	)
	var default_exact: bool = (
		_state_matches_golden(default_state, 40, 1_077_250, 152_250, 3090, 2030, 30_900, 91_350, 90, 0, 60, 0)
		and default_trace.size() == 37
		and _trace_source_order_matches(default_trace, false)
		and _sum_market_delta(default_trace, EffectContributionType.SUBJECT_CONSUMER, EffectContributionType.REASON_MARKET_SERVED) == 90
		and _sum_market_delta(default_trace, EffectContributionType.SUBJECT_CONSUMER, EffectContributionType.REASON_MARKET_SHARE_CHANGE) == 90
		and _sum_market_delta(default_trace, EffectContributionType.SUBJECT_CONSUMER, EffectContributionType.REASON_MARKET_REVENUE_CHANGE) == 900
		and _sum_market_delta(default_trace, EffectContributionType.SUBJECT_DEVELOPER_API, EffectContributionType.REASON_MARKET_SERVED) == 60
		and _sum_market_delta(default_trace, EffectContributionType.SUBJECT_DEVELOPER_API, EffectContributionType.REASON_MARKET_SHARE_CHANGE) == 30
		and _sum_market_delta(default_trace, EffectContributionType.SUBJECT_DEVELOPER_API, EffectContributionType.REASON_MARKET_REVENUE_CHANGE) == 1_350
	)
	var constrained_exact: bool = (
		_state_matches_golden(constrained_state, 70, 912_640, 59_640, 2460, 1100, 9_840, 19_800, 36, 54, 24, 36)
		and constrained_trace.size() == 46
		and _trace_source_order_matches(constrained_trace, true)
		and _sum_market_delta(constrained_trace, EffectContributionType.SUBJECT_CONSUMER, EffectContributionType.REASON_MARKET_SERVED) == 36
		and _sum_market_delta(constrained_trace, EffectContributionType.SUBJECT_CONSUMER, EffectContributionType.REASON_MARKET_UNMET) == 54
		and _sum_market_delta(constrained_trace, EffectContributionType.SUBJECT_CONSUMER, EffectContributionType.REASON_MARKET_SHARE_CHANGE) == -540
		and _sum_market_delta(constrained_trace, EffectContributionType.SUBJECT_CONSUMER, EffectContributionType.REASON_MARKET_REVENUE_CHANGE) == -20_160
		and _sum_market_delta(constrained_trace, EffectContributionType.SUBJECT_DEVELOPER_API, EffectContributionType.REASON_MARKET_SERVED) == 24
		and _sum_market_delta(constrained_trace, EffectContributionType.SUBJECT_DEVELOPER_API, EffectContributionType.REASON_MARKET_UNMET) == 36
		and _sum_market_delta(constrained_trace, EffectContributionType.SUBJECT_DEVELOPER_API, EffectContributionType.REASON_MARKET_SHARE_CHANGE) == -900
		and _sum_market_delta(constrained_trace, EffectContributionType.SUBJECT_DEVELOPER_API, EffectContributionType.REASON_MARKET_REVENUE_CHANGE) == -70_200
	)

	var zero_market_state: GameStateType = GameStateType.new(
		CompanyStateType.new(1_000_000, 120_000, 80_000),
		_create_project(ProjectStateType.Lifecycle.ACTIVE),
		ComputeStateType.new(100, 10, 50, 70)
	)
	var zero_market_result: TickResultType = engine.advance_quarter(zero_market_state)
	var zero_market_snapshot: GameStateType = zero_market_result.get_state_snapshot()
	var zero_market_trace: Array[EffectContributionType] = (
		zero_market_result.get_contributions()
	)
	var zero_market_compatible: bool = (
		zero_market_result.is_successful()
		and zero_market_snapshot.get_company().get_cash_cents() == 1_075_000
		and zero_market_snapshot.get_company().get_monthly_revenue_cents() == 150_000
		and zero_market_trace.size() == 22
		and _sum_source(zero_market_trace, EffectContributionType.SOURCE_MARKET) == 0
	)
	return default_exact and constrained_exact and zero_market_compatible


static func _test_failure_positions() -> bool:
	var engine: SimulationEngineType = SimulationEngineType.new()
	var market_system: MarketSystemType = MarketSystemType.new()
	for failure_month in range(1, 4):
		var cumulative_before: int = MAX_SIGNED_INT - (30 * (failure_month - 1))
		var probe_state: GameStateType = _create_active_state(
			40,
			_create_market(cumulative_before)
		)
		for successful_month in range(failure_month - 1):
			var success_result: EffectBatchResultType = market_system.settle_month(
				probe_state.get_company(),
				probe_state.get_compute(),
				probe_state.get_market()
			)
			if (
				not success_result.is_successful()
				or probe_state.get_market()
					.get_consumer_cumulative_served_compute_unit_months()
					!= cumulative_before + (30 * (successful_month + 1))
			):
				return false
		var probe_before_failure: GameStateType = probe_state.copy()
		var probe_failure: EffectBatchResultType = market_system.settle_month(
			probe_state.get_company(),
			probe_state.get_compute(),
			probe_state.get_market()
		)
		if (
			probe_failure.is_successful()
			or probe_failure.get_error_code()
				!= EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW
			or not probe_failure.get_contributions().is_empty()
			or not _game_states_equal(probe_state, probe_before_failure)
		):
			return false

		var input_state: GameStateType = _create_active_state(
			40,
			_create_market(cumulative_before)
		)
		var before: GameStateType = input_state.copy()
		var result: TickResultType = engine.advance_quarter(input_state)
		if (
			result == null
			or result.is_successful()
			or result.get_state_snapshot() != null
			or not result.get_contributions().is_empty()
			or not _game_states_equal(input_state, before)
		):
			return false
	return true


static func _test_game_session_boundary() -> bool:
	var initial_state: GameStateType = _create_planning_state()
	var session: GameSessionType = GameSessionType.new(initial_state)
	var observer: CommitObserver = CommitObserver.new(session)
	session.committed_result.connect(observer.capture)
	var initial_view_model: DashboardViewModelType = session.get_current_view_model()
	var initial_snapshot: GameStateType = session.get_state_snapshot()
	if (
		initial_view_model.get_consumer_market_text()
			!= "Consumer: 3,000 bps | workload 30 | 30,000 cents/month"
		or initial_view_model.get_developer_api_market_text()
			!= "Developer/API: 2,000 bps | workload 20 | 90,000 cents/month"
	):
		return false

	var rejected: bool = (
		not session.submit_command(null).is_successful()
		and not session.submit_command(GameCommandType.new()).is_successful()
		and not session.submit_command(UnknownGameCommand.new()).is_successful()
		and not session.submit_command(DerivedSetComputeAllocationCommand.new(70)).is_successful()
	)
	if (
		not rejected
		or observer.count != 0
		or not _game_states_equal(session.get_state_snapshot(), initial_snapshot)
		or session.get_current_view_model() != initial_view_model
		or not session.get_last_committed_contributions().is_empty()
	):
		return false

	if not session.submit_command(SetComputeAllocationCommandType.new(70)).is_successful():
		return false
	if observer.count != 1 or not observer.every_signal_saw_committed_values:
		return false
	if not session.submit_command(StartProjectCommandType.new()).is_successful():
		return false
	if observer.count != 2 or not observer.every_signal_saw_committed_values:
		return false
	if not session.submit_command(AdvanceQuarterCommandType.new()).is_successful():
		return false
	var final_view_model: DashboardViewModelType = session.get_current_view_model()
	var final_state: GameStateType = session.get_state_snapshot()
	if (
		observer.count != 3
		or not observer.every_signal_saw_committed_values
		or not _state_matches_golden(final_state, 70, 912_640, 59_640, 2460, 1100, 9_840, 19_800, 36, 54, 24, 36)
		or final_view_model.get_consumer_market_text()
			!= "Consumer: served 36/90, share -540 → 2,460 bps, revenue -20,160 → 9,840"
		or final_view_model.get_developer_api_market_text()
			!= "Developer/API: served 24/60, share -900 → 1,100 bps, revenue -70,200 → 19,800"
		or session.get_last_committed_contributions().size() != 46
	):
		return false

	var failing_state: GameStateType = _create_active_state(
		40,
		_create_market(MAX_SIGNED_INT)
	)
	var failing_session: GameSessionType = GameSessionType.new(failing_state)
	var failing_observer: CommitObserver = CommitObserver.new(failing_session)
	failing_session.committed_result.connect(failing_observer.capture)
	var failure_before: GameStateType = failing_session.get_state_snapshot()
	var failure_view_model: DashboardViewModelType = failing_session.get_current_view_model()
	return (
		not failing_session.submit_command(AdvanceQuarterCommandType.new()).is_successful()
		and failing_observer.count == 0
		and _game_states_equal(failing_session.get_state_snapshot(), failure_before)
		and failing_session.get_current_view_model() == failure_view_model
		and failing_session.get_last_committed_contributions().is_empty()
	)


static func _test_deterministic_sessions() -> bool:
	for training_units in [40, 70]:
		var first: GameSessionType = GameSessionType.new(_create_active_state(training_units))
		var second: GameSessionType = GameSessionType.new(_create_active_state(training_units))
		if (
			not first.submit_command(AdvanceQuarterCommandType.new()).is_successful()
			or not second.submit_command(AdvanceQuarterCommandType.new()).is_successful()
			or not _game_states_equal(first.get_state_snapshot(), second.get_state_snapshot())
			or not _traces_equal(first.get_last_committed_contributions(), second.get_last_committed_contributions())
			or not _view_models_equal(first.get_current_view_model(), second.get_current_view_model())
		):
			return false
		var first_view_model: DashboardViewModelType = first.get_current_view_model()
		if training_units == 40:
			if (
				first_view_model.get_consumer_market_text()
					!= "Consumer: served 90/90, share +90 → 3,090 bps, revenue +900 → 30,900"
				or first_view_model.get_developer_api_market_text()
					!= "Developer/API: served 60/60, share +30 → 2,030 bps, revenue +1,350 → 91,350"
			):
				return false
		elif (
			first_view_model.get_consumer_market_text()
				!= "Consumer: served 36/90, share -540 → 2,460 bps, revenue -20,160 → 9,840"
			or first_view_model.get_developer_api_market_text()
				!= "Developer/API: served 24/60, share -900 → 1,100 bps, revenue -70,200 → 19,800"
		):
			return false
	return true


static func _create_planning_state() -> GameStateType:
	return GameStateType.new(
		CompanyStateType.new(1_000_000, 120_000, 80_000),
		_create_project(ProjectStateType.Lifecycle.NOT_STARTED),
		ComputeStateType.new(100, 10, 50, 40),
		_create_market()
	)


static func _create_active_state(
	training_units: int,
	market: MarketStateType = null
) -> GameStateType:
	return GameStateType.new(
		CompanyStateType.new(1_000_000, 120_000, 80_000),
		_create_project(ProjectStateType.Lifecycle.ACTIVE),
		ComputeStateType.new(100, 10, 50, training_units),
		_create_market() if market == null else market
	)


static func _create_project(lifecycle: ProjectStateType.Lifecycle) -> ProjectStateType:
	return ProjectStateType.new(PROJECT_ID, 3, 25_000, 30_000, lifecycle, 0)


static func _create_market(consumer_cumulative_served: int = 0) -> MarketStateType:
	return MarketStateType.new(
		30, 20, 6_000, 3_000, 2_000, 100_000, 450_000, 30, 10, 10, 25,
		30, 20, 30_000, 90_000, consumer_cumulative_served
	)


static func _state_matches_golden(
	state: GameStateType,
	training_units: int,
	cash_cents: int,
	monthly_revenue_cents: int,
	consumer_share_bps: int,
	developer_share_bps: int,
	consumer_revenue_cents: int,
	developer_revenue_cents: int,
	consumer_served: int,
	consumer_unmet: int,
	developer_served: int,
	developer_unmet: int
) -> bool:
	if state == null:
		return false
	var market: MarketStateType = state.get_market()
	return (
		state.get_clock().get_elapsed_months() == 3
		and state.get_company().get_cash_cents() == cash_cents
		and state.get_company().get_monthly_revenue_cents() == monthly_revenue_cents
		and state.get_project().get_lifecycle() == ProjectStateType.Lifecycle.COMPLETED
		and state.get_project().get_progress_months() == 3
		and state.get_compute().get_training_allocation_units_per_month() == training_units
		and state.get_compute().get_cumulative_training_compute_unit_months() == training_units * 3
		and state.get_compute().get_cumulative_served_inference_compute_unit_months() == consumer_served + developer_served
		and state.get_compute().get_cumulative_unmet_inference_compute_unit_months() == consumer_unmet + developer_unmet
		and market.get_consumer_player_share_bps() == consumer_share_bps
		and market.get_developer_api_player_share_bps() == developer_share_bps
		and market.get_consumer_current_market_revenue_cents() == consumer_revenue_cents
		and market.get_developer_api_current_market_revenue_cents() == developer_revenue_cents
		and market.get_consumer_cumulative_served_compute_unit_months() == consumer_served
		and market.get_consumer_cumulative_unmet_compute_unit_months() == consumer_unmet
		and market.get_developer_api_cumulative_served_compute_unit_months() == developer_served
		and market.get_developer_api_cumulative_unmet_compute_unit_months() == developer_unmet
	)


static func _trace_source_order_matches(
	trace: Array[EffectContributionType],
	with_shortage: bool
) -> bool:
	var expected_sources: Array[StringName] = []
	for month_index in 3:
		expected_sources.append(EffectContributionType.SOURCE_PROJECT)
		expected_sources.append(EffectContributionType.SOURCE_PROJECT)
		if month_index == 2:
			expected_sources.append(EffectContributionType.SOURCE_PROJECT)
		expected_sources.append(EffectContributionType.SOURCE_COMPUTE)
		expected_sources.append(EffectContributionType.SOURCE_COMPUTE)
		if with_shortage:
			expected_sources.append(EffectContributionType.SOURCE_COMPUTE)
		expected_sources.append(EffectContributionType.SOURCE_FINANCE)
		expected_sources.append(EffectContributionType.SOURCE_FINANCE)
		for _market_index in (8 if with_shortage else 6):
			expected_sources.append(EffectContributionType.SOURCE_MARKET)
	if trace.size() != expected_sources.size():
		return false
	for index in trace.size():
		if trace[index].get_source_key() != expected_sources[index]:
			return false
	return _market_effect_blocks_are_ordered(trace, with_shortage)


static func _market_effect_blocks_are_ordered(
	trace: Array[EffectContributionType],
	with_shortage: bool
) -> bool:
	var market_effects: Array[EffectContributionType] = []
	for contribution in trace:
		if contribution.get_source_key() == EffectContributionType.SOURCE_MARKET:
			market_effects.append(contribution)
	var block_size: int = 8 if with_shortage else 6
	for month_index in 3:
		var offset: int = month_index * block_size
		var expected_reasons: Array[StringName] = [
			EffectContributionType.REASON_MARKET_SERVED,
		]
		if with_shortage:
			expected_reasons.append(EffectContributionType.REASON_MARKET_UNMET)
		expected_reasons.append(EffectContributionType.REASON_MARKET_SHARE_CHANGE)
		expected_reasons.append(EffectContributionType.REASON_MARKET_REVENUE_CHANGE)
		var consumer_count: int = expected_reasons.size()
		for reason_index in consumer_count:
			if (
				market_effects[offset + reason_index].get_subject_key()
					!= EffectContributionType.SUBJECT_CONSUMER
				or market_effects[offset + reason_index].get_reason_key()
					!= expected_reasons[reason_index]
			):
				return false
		for reason_index in consumer_count:
			if (
				market_effects[offset + consumer_count + reason_index].get_subject_key()
					!= EffectContributionType.SUBJECT_DEVELOPER_API
				or market_effects[offset + consumer_count + reason_index].get_reason_key()
					!= expected_reasons[reason_index]
			):
				return false
	return true


static func _sum_market_delta(
	trace: Array[EffectContributionType],
	subject: StringName,
	reason: StringName
) -> int:
	var total: int = 0
	for contribution in trace:
		if (
			contribution.get_source_key() == EffectContributionType.SOURCE_MARKET
			and contribution.get_subject_key() == subject
			and contribution.get_reason_key() == reason
		):
			total += contribution.get_delta()
	return total


static func _sum_source(
	trace: Array[EffectContributionType],
	source: StringName
) -> int:
	var count: int = 0
	for contribution in trace:
		if contribution.get_source_key() == source:
			count += 1
	return count


static func _game_states_equal(first: GameStateType, second: GameStateType) -> bool:
	if first == null or second == null:
		return first == second
	return (
		first.get_clock().get_elapsed_months() == second.get_clock().get_elapsed_months()
		and first.get_company().get_cash_cents() == second.get_company().get_cash_cents()
		and first.get_company().get_monthly_revenue_cents() == second.get_company().get_monthly_revenue_cents()
		and first.get_company().get_monthly_operating_cost_cents() == second.get_company().get_monthly_operating_cost_cents()
		and first.get_project().get_lifecycle() == second.get_project().get_lifecycle()
		and first.get_project().get_progress_months() == second.get_project().get_progress_months()
		and first.get_compute().get_training_allocation_units_per_month() == second.get_compute().get_training_allocation_units_per_month()
		and first.get_compute().get_cumulative_training_compute_unit_months() == second.get_compute().get_cumulative_training_compute_unit_months()
		and first.get_compute().get_cumulative_served_inference_compute_unit_months() == second.get_compute().get_cumulative_served_inference_compute_unit_months()
		and first.get_compute().get_cumulative_unmet_inference_compute_unit_months() == second.get_compute().get_cumulative_unmet_inference_compute_unit_months()
		and _market_states_equal(first.get_market(), second.get_market())
	)


static func _market_states_equal(first: MarketStateType, second: MarketStateType) -> bool:
	return (
		first.get_consumer_workload_units_per_month() == second.get_consumer_workload_units_per_month()
		and first.get_developer_api_workload_units_per_month() == second.get_developer_api_workload_units_per_month()
		and first.get_consumer_service_allocation_bps() == second.get_consumer_service_allocation_bps()
		and first.get_consumer_player_share_bps() == second.get_consumer_player_share_bps()
		and first.get_developer_api_player_share_bps() == second.get_developer_api_player_share_bps()
		and first.get_consumer_current_served_units_per_month() == second.get_consumer_current_served_units_per_month()
		and first.get_developer_api_current_served_units_per_month() == second.get_developer_api_current_served_units_per_month()
		and first.get_consumer_current_market_revenue_cents() == second.get_consumer_current_market_revenue_cents()
		and first.get_developer_api_current_market_revenue_cents() == second.get_developer_api_current_market_revenue_cents()
		and first.get_consumer_cumulative_served_compute_unit_months() == second.get_consumer_cumulative_served_compute_unit_months()
		and first.get_consumer_cumulative_unmet_compute_unit_months() == second.get_consumer_cumulative_unmet_compute_unit_months()
		and first.get_developer_api_cumulative_served_compute_unit_months() == second.get_developer_api_cumulative_served_compute_unit_months()
		and first.get_developer_api_cumulative_unmet_compute_unit_months() == second.get_developer_api_cumulative_unmet_compute_unit_months()
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


static func _view_models_equal(
	first: DashboardViewModelType,
	second: DashboardViewModelType
) -> bool:
	return (
		first.get_date_text() == second.get_date_text()
		and first.get_cash_text() == second.get_cash_text()
		and first.get_monthly_revenue_text() == second.get_monthly_revenue_text()
		and first.get_project_text() == second.get_project_text()
		and first.get_compute_plan_text() == second.get_compute_plan_text()
		and first.get_training_work_text() == second.get_training_work_text()
		and first.get_inference_served_text() == second.get_inference_served_text()
		and first.get_inference_unmet_text() == second.get_inference_unmet_text()
		and first.get_consumer_market_text() == second.get_consumer_market_text()
		and first.get_developer_api_market_text() == second.get_developer_api_market_text()
	)


static func _report(report: Callable, condition: bool, description: String) -> void:
	report.call(condition, description)
