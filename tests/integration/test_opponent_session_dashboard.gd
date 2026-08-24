extends RefCounted


const GameCommandType = preload("res://simulation/commands/game_command.gd")
const StartProjectCommandType = preload(
	"res://simulation/commands/start_project_command.gd"
)
const AdvanceQuarterCommandType = preload(
	"res://simulation/commands/advance_quarter_command.gd"
)
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
const OpponentStateType = preload("res://simulation/state/opponent_state.gd")
const OpponentPersonalityType = preload("res://simulation/ai/opponent_personality.gd")
const OpponentPlanningSnapshotType = preload(
	"res://simulation/ai/opponent_planning_snapshot.gd"
)
const NamedRngStateType = preload("res://simulation/rng/named_rng_state.gd")
const MarketSystemType = preload("res://simulation/systems/market_system.gd")
const EffectContributionType = preload(
	"res://simulation/events/effect_contribution.gd"
)
const GameSessionType = preload("res://application/game_session.gd")
const DashboardViewModelType = preload(
	"res://application/view_models/dashboard_view_model.gd"
)
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
	var all_signals_saw_committed_values: bool = true
	var saw_complete_rival_quarter: bool = false
	var _session

	func _init(p_session) -> void:
		_session = p_session

	func capture(view_model: DashboardViewModelType) -> void:
		count += 1
		var snapshot: GameStateType = _session.get_state_snapshot()
		var committed: bool = (
			snapshot != null
			and _session.get_current_view_model() == view_model
		)
		var contributions: Array[EffectContributionType] = (
			_session.get_last_committed_contributions()
		)
		if contributions.size() == 52:
			committed = (
				committed
				and snapshot.get_clock().get_elapsed_months() == 3
				and snapshot.get_company().get_cash_cents() == 1_071_130
				and snapshot.get_named_rng().get_ai_stream_state() == 1_278_240_558
				and _session.get_cached_opponent_planning_snapshot()
					.get_elapsed_months() == 3
				and _session.get_last_rival_contributions().size() == 15
			)
			saw_complete_rival_quarter = committed
		all_signals_saw_committed_values = (
			all_signals_saw_committed_values and committed
		)


static func run(report: Callable) -> void:
	_report(
		report,
		_test_active_quarter_order_and_rollback(),
		"TP-022 opponent quarter preserves ordered effects and full rollback"
	)
	_report(
		report,
		_test_zero_opponent_compatibility(),
		"TP-022 zero opponent preserves every TP-021 Golden and trace"
	)
	_report(
		report,
		_test_game_session_publication_and_cache(),
		"TP-022 GameSession publishes only committed rival decisions"
	)


static func report_dashboard_scene(report: Callable, condition: bool) -> void:
	_report(
		report,
		condition,
		"TP-022 dashboard explains rival signal action and market pressure"
	)


static func report_dashboard_layout(report: Callable, condition: bool) -> void:
	_report(
		report,
		condition,
		"TP-022 dashboard fits 1280x720 and 1920x1080"
	)


static func _test_active_quarter_order_and_rollback() -> bool:
	var engine: SimulationEngineType = SimulationEngineType.new()
	var personality: OpponentPersonalityType = _create_personality()
	var input_state: GameStateType = _create_state(
		40,
		ProjectStateType.Lifecycle.ACTIVE,
		true
	)
	var input_before: GameStateType = input_state.copy()
	var result: TickResultType = engine.advance_quarter(
		input_state,
		_create_snapshot(input_state),
		personality
	)
	if result == null or not result.is_successful():
		return false
	var state: GameStateType = result.get_state_snapshot()
	var trace: Array[EffectContributionType] = result.get_contributions()
	var active_golden: bool = (
		_game_states_equal(input_state, input_before)
		and state != null
		and state.get_clock().get_elapsed_months() == 3
		and state.get_company().get_cash_cents() == 1_071_130
		and state.get_company().get_monthly_revenue_cents() == 146_130
		and state.get_company().get_monthly_operating_cost_cents() == 80_000
		and state.get_project().get_lifecycle() == ProjectStateType.Lifecycle.COMPLETED
		and state.get_project().get_progress_months() == 3
		and _compute_fields(state.get_compute()) == [100, 10, 50, 40, 120, 150, 0]
		and state.get_market().get_consumer_player_share_bps() == 3_018
		and state.get_market().get_developer_api_player_share_bps() == 1_910
		and state.get_market().get_consumer_current_market_revenue_cents() == 30_180
		and state.get_market().get_developer_api_current_market_revenue_cents()
			== 85_950
		and state.get_market().get_consumer_outside_share_bps() == 6_982
		and state.get_market().get_developer_api_outside_share_bps() == 8_090
		and _compute_fields(state.get_opponent().get_compute())
			== [100, 10, 50, 70, 210, 60, 90]
		and state.get_opponent().get_last_candidate_key()
			== OpponentPersonalityType.CANDIDATE_PLAN_70_CLOSE_TRAINING_GAP
		and state.get_opponent().get_last_training_units_per_month() == 70
		and state.get_opponent().get_last_reason_key()
			== OpponentPersonalityType.REASON_CLOSE_TRAINING_GAP
		and state.get_opponent().get_last_base_utility_points() == 680
		and state.get_opponent().get_last_noise_points() == 8
		and state.get_opponent().get_last_total_utility_points() == 688
		and _rng_fields(state.get_named_rng())
			== [7, 1, 1_278_240_558, 11, 13]
		and _active_trace_matches(trace)
	)
	if not active_golden or not _non_default_split_uses_market_rule():
		return false

	for failure_month in range(1, 4):
		var served_before: int = MAX_SIGNED_INT - (20 * (failure_month - 1))
		var opponent_overflow_state: GameStateType = _create_state(
			40,
			ProjectStateType.Lifecycle.ACTIVE,
			true,
			6_000,
			2,
			5,
			0,
			served_before,
			0
		)
		if not _failed_quarter_preserves_all(
			engine,
			opponent_overflow_state,
			_create_snapshot(opponent_overflow_state),
			personality
		):
			return false

		var clock_failure_state: GameStateType = _create_state(
			40,
			ProjectStateType.Lifecycle.ACTIVE,
			true
		)
		if not clock_failure_state.get_clock().advance_months(
			MAX_SIGNED_INT - failure_month + 1
		):
			return false
		if not _failed_quarter_preserves_all(
			engine,
			clock_failure_state,
			_create_snapshot(clock_failure_state),
			personality
		):
			return false

	var pressure_overflow_state: GameStateType = _create_state(
		40,
		ProjectStateType.Lifecycle.ACTIVE,
		true,
		6_000,
		MAX_SIGNED_INT,
		5
	)
	if not _failed_quarter_preserves_all(
		engine,
		pressure_overflow_state,
		_create_snapshot(pressure_overflow_state),
		personality
	):
		return false

	for stale_snapshot in [
		OpponentPlanningSnapshotType.new(1, 3_000, 2_000),
		OpponentPlanningSnapshotType.new(0, 3_001, 2_000),
		OpponentPlanningSnapshotType.new(0, 3_000, 2_001),
	]:
		var stale_state: GameStateType = _create_state(
			40,
			ProjectStateType.Lifecycle.ACTIVE,
			true
		)
		if not _failed_quarter_preserves_all(
			engine,
			stale_state,
			stale_snapshot,
			personality
		):
			return false

	var wrong_personality: OpponentPersonalityType = _create_personality(&"wrong")
	var mismatched_state: GameStateType = _create_state(
		40,
		ProjectStateType.Lifecycle.ACTIVE,
		true
	)
	if not _failed_quarter_preserves_all(
		engine,
		mismatched_state,
		_create_snapshot(mismatched_state),
		wrong_personality
	):
		return false

	var active_partial_source: GameStateType = _create_state(
		40,
		ProjectStateType.Lifecycle.ACTIVE,
		true
	)
	if not _failed_quarter_preserves_all(
		engine,
		active_partial_source,
		_create_snapshot(active_partial_source),
		null
	):
		return false
	var active_without_rng: GameStateType = GameStateType.new(
		active_partial_source.get_company(),
		active_partial_source.get_project(),
		active_partial_source.get_compute(),
		active_partial_source.get_market(),
		active_partial_source.get_opponent()
	)
	if not _failed_quarter_preserves_all(
		engine,
		active_without_rng,
		_create_snapshot(active_without_rng),
		personality
	):
		return false

	var inactive_state: GameStateType = _create_state(
		40,
		ProjectStateType.Lifecycle.ACTIVE,
		false
	)
	if not _failed_quarter_preserves_all(
		engine,
		inactive_state,
		null,
		personality
	):
		return false
	var inactive_with_rng: GameStateType = GameStateType.new(
		inactive_state.get_company(),
		inactive_state.get_project(),
		inactive_state.get_compute(),
		inactive_state.get_market(),
		inactive_state.get_opponent(),
		NamedRngStateType.create_fresh_version_one(7)
	)
	if not _failed_quarter_preserves_all(
		engine,
		inactive_with_rng,
		null,
		null
	):
		return false
	var partial_inactive: GameStateType = GameStateType.new(
		inactive_state.get_company(),
		inactive_state.get_project(),
		inactive_state.get_compute(),
		_create_market(6_000, 2, 5)
	)
	return _failed_quarter_preserves_all(engine, partial_inactive, null, null)


static func _test_zero_opponent_compatibility() -> bool:
	var engine: SimulationEngineType = SimulationEngineType.new()
	var default_state: GameStateType = _create_state(
		40,
		ProjectStateType.Lifecycle.ACTIVE,
		false
	)
	var constrained_state: GameStateType = _create_state(
		70,
		ProjectStateType.Lifecycle.ACTIVE,
		false
	)
	var default_result: TickResultType = engine.advance_quarter(default_state)
	var constrained_result: TickResultType = engine.advance_quarter(constrained_state)
	var repeated_default: TickResultType = engine.advance_quarter(
		_create_state(40, ProjectStateType.Lifecycle.ACTIVE, false)
	)
	var repeated_constrained: TickResultType = engine.advance_quarter(
		_create_state(70, ProjectStateType.Lifecycle.ACTIVE, false)
	)
	if (
		default_result == null
		or not default_result.is_successful()
		or constrained_result == null
		or not constrained_result.is_successful()
		or repeated_default == null
		or not repeated_default.is_successful()
		or repeated_constrained == null
		or not repeated_constrained.is_successful()
	):
		return false
	var default_final: GameStateType = default_result.get_state_snapshot()
	var constrained_final: GameStateType = constrained_result.get_state_snapshot()
	var default_trace: Array[EffectContributionType] = default_result.get_contributions()
	var constrained_trace: Array[EffectContributionType] = (
		constrained_result.get_contributions()
	)
	var default_exact: bool = (
		_legacy_state_matches(
			default_final,
			40,
			1_077_250,
			152_250,
			3_090,
			2_030,
			30_900,
			91_350,
			90,
			0,
			60,
			0
		)
		and default_trace.size() == 37
		and _legacy_trace_order_matches(default_trace, false)
		and _trace_has_no_rival_effect(default_trace)
		and _game_states_equal(
			default_final,
			repeated_default.get_state_snapshot()
		)
		and _traces_equal(default_trace, repeated_default.get_contributions())
	)
	var constrained_exact: bool = (
		_legacy_state_matches(
			constrained_final,
			70,
			912_640,
			59_640,
			2_460,
			1_100,
			9_840,
			19_800,
			36,
			54,
			24,
			36
		)
		and constrained_trace.size() == 46
		and _legacy_trace_order_matches(constrained_trace, true)
		and _trace_has_no_rival_effect(constrained_trace)
		and _game_states_equal(
			constrained_final,
			repeated_constrained.get_state_snapshot()
		)
		and _traces_equal(
			constrained_trace,
			repeated_constrained.get_contributions()
		)
	)

	var session: GameSessionType = GameSessionType.new(
		_create_state(40, ProjectStateType.Lifecycle.NOT_STARTED, false)
	)
	var initial_view_model: DashboardViewModelType = session.get_current_view_model()
	var session_exact: bool = (
		_rival_view_model_is_empty(initial_view_model)
		and session.get_last_rival_contributions().is_empty()
		and session.submit_command(StartProjectCommandType.new()).is_successful()
		and session.submit_command(AdvanceQuarterCommandType.new()).is_successful()
		and session.get_last_committed_contributions().size() == 37
		and session.get_last_rival_contributions().is_empty()
		and _rival_view_model_is_empty(session.get_current_view_model())
		and session.get_current_view_model().get_consumer_market_text()
			== "Consumer: served 90/90, share +90 → 3,090 bps, revenue +900 → 30,900"
		and session.get_current_view_model().get_developer_api_market_text()
			== "Developer/API: served 60/60, share +30 → 2,030 bps, revenue +1,350 → 91,350"
	)
	return default_exact and constrained_exact and session_exact


static func _test_game_session_publication_and_cache() -> bool:
	var personality: OpponentPersonalityType = _create_personality()
	var fairness_session: GameSessionType = GameSessionType.new(
		_create_state(40, ProjectStateType.Lifecycle.NOT_STARTED, true),
		personality
	)
	var fairness_observer: CommitObserver = CommitObserver.new(fairness_session)
	fairness_session.committed_result.connect(fairness_observer.capture)
	var initial_view_model: DashboardViewModelType = fairness_session.get_current_view_model()
	var initial_snapshot: OpponentPlanningSnapshotType = (
		fairness_session.get_cached_opponent_planning_snapshot()
	)
	var initial_signal_exact: bool = (
		_initial_rival_view_model_matches(initial_view_model)
		and initial_snapshot.get_elapsed_months() == 0
		and initial_snapshot.get_consumer_player_share_bps() == 3_000
		and initial_snapshot.get_developer_api_player_share_bps() == 2_000
		and fairness_session.get_state_snapshot().get_named_rng().get_ai_stream_state() == 7
	)
	var initial_state: GameStateType = fairness_session.get_state_snapshot()
	var null_rejected: bool = not fairness_session.submit_command(null).is_successful()
	var base_rejected: bool = not fairness_session.submit_command(
		GameCommandType.new()
	).is_successful()
	var unknown_rejected: bool = not fairness_session.submit_command(
		UnknownGameCommand.new()
	).is_successful()
	var derived_rejected: bool = not fairness_session.submit_command(
		DerivedSetComputeAllocationCommand.new(70)
	).is_successful()
	var rejects_preserved: bool = (
		fairness_observer.count == 0
		and fairness_session.get_current_view_model() == initial_view_model
		and _game_states_equal(fairness_session.get_state_snapshot(), initial_state)
		and fairness_session.get_last_committed_contributions().is_empty()
		and fairness_session.get_last_rival_contributions().is_empty()
	)
	var allocation_succeeded: bool = fairness_session.submit_command(
		SetComputeAllocationCommandType.new(70)
	).is_successful()
	var after_allocation: DashboardViewModelType = fairness_session.get_current_view_model()
	var start_succeeded: bool = fairness_session.submit_command(
		StartProjectCommandType.new()
	).is_successful()
	var after_start: DashboardViewModelType = fairness_session.get_current_view_model()
	var cached_signal_is_fair: bool = (
		allocation_succeeded
		and start_succeeded
		and fairness_observer.count == 2
		and fairness_observer.all_signals_saw_committed_values
		and _initial_rival_view_model_matches(after_allocation)
		and _initial_rival_view_model_matches(after_start)
		and fairness_session.get_cached_opponent_planning_snapshot()
			.get_elapsed_months() == 0
		and fairness_session.get_cached_opponent_planning_snapshot()
			.get_consumer_player_share_bps() == 3_000
		and fairness_session.get_state_snapshot().get_compute()
			.get_training_allocation_units_per_month() == 70
		and fairness_session.get_state_snapshot().get_project().get_lifecycle()
			== ProjectStateType.Lifecycle.ACTIVE
		and fairness_session.get_state_snapshot().get_named_rng()
			.get_ai_stream_state() == 7
		and fairness_session.get_last_rival_contributions().is_empty()
	)
	if (
		not initial_signal_exact
		or not null_rejected
		or not base_rejected
		or not unknown_rejected
		or not derived_rejected
		or not rejects_preserved
		or not cached_signal_is_fair
	):
		return false

	var session: GameSessionType = GameSessionType.new(
		_create_state(40, ProjectStateType.Lifecycle.NOT_STARTED, true),
		personality
	)
	var observer: CommitObserver = CommitObserver.new(session)
	session.committed_result.connect(observer.capture)
	if (
		not session.submit_command(StartProjectCommandType.new()).is_successful()
		or not session.submit_command(AdvanceQuarterCommandType.new()).is_successful()
	):
		return false
	var committed_state: GameStateType = session.get_state_snapshot()
	var committed_view_model: DashboardViewModelType = session.get_current_view_model()
	var cached_snapshot: OpponentPlanningSnapshotType = (
		session.get_cached_opponent_planning_snapshot()
	)
	var rival_slice_before: Array[EffectContributionType] = (
		session.get_last_rival_contributions()
	)
	var full_trace_before: Array[EffectContributionType] = (
		session.get_last_committed_contributions()
	)
	var publication_exact: bool = (
		observer.count == 2
		and observer.all_signals_saw_committed_values
		and observer.saw_complete_rival_quarter
		and full_trace_before.size() == 52
		and rival_slice_before.size() == 15
		and _rival_slice_matches(rival_slice_before)
		and cached_snapshot.get_elapsed_months() == 3
		and cached_snapshot.get_consumer_player_share_bps() == 3_018
		and cached_snapshot.get_developer_api_player_share_bps() == 1_910
		and committed_state.get_named_rng().get_ai_stream_state() == 1_278_240_558
		and committed_state.get_named_rng().get_events_stream_state() == 11
		and committed_state.get_named_rng().get_market_stream_state() == 13
		and _committed_rival_view_model_matches(committed_view_model)
		and committed_view_model.get_cash_text() == "Cash: 1,071,130 cents"
		and committed_view_model.get_monthly_revenue_text()
			== "Monthly revenue: 146,130 cents"
		and committed_view_model.get_consumer_market_text()
			== "Consumer: served 90/90, share +18 → 3,018 bps, revenue +180 → 30,180"
		and committed_view_model.get_developer_api_market_text()
			== "Developer/API: served 60/60, share -90 → 1,910 bps, revenue -4,050 → 85,950"
	)
	if not publication_exact:
		return false

	var returned_state: GameStateType = session.get_state_snapshot()
	var returned_snapshot: OpponentPlanningSnapshotType = (
		session.get_cached_opponent_planning_snapshot()
	)
	var state_copy_changed: bool = returned_state.get_clock().advance_month()
	rival_slice_before.clear()
	var protected_access: bool = (
		state_copy_changed
		and session.get_state_snapshot().get_clock().get_elapsed_months() == 3
		and returned_snapshot != session.get_cached_opponent_planning_snapshot()
		and session.get_cached_opponent_planning_snapshot().get_elapsed_months() == 3
		and session.get_last_rival_contributions().size() == 15
	)

	var set_after_quarter: bool = session.submit_command(
		SetComputeAllocationCommandType.new(70)
	).is_successful()
	var after_set_state: GameStateType = session.get_state_snapshot()
	var after_set_view_model: DashboardViewModelType = session.get_current_view_model()
	var retained_rival_slice: Array[EffectContributionType] = (
		session.get_last_rival_contributions()
	)
	var rejected_start: bool = not session.submit_command(
		StartProjectCommandType.new()
	).is_successful()
	var retained_after_commands: bool = (
		set_after_quarter
		and rejected_start
		and observer.count == 3
		and observer.all_signals_saw_committed_values
		and session.get_last_committed_contributions().is_empty()
		and retained_rival_slice.size() == 15
		and _rival_slice_matches(retained_rival_slice)
		and _traces_equal(retained_rival_slice, session.get_last_rival_contributions())
		and after_set_state.get_compute().get_training_allocation_units_per_month() == 70
		and after_set_state.get_named_rng().get_ai_stream_state() == 1_278_240_558
		and session.get_cached_opponent_planning_snapshot().get_elapsed_months() == 3
		and _committed_rival_view_model_matches(after_set_view_model)
		and session.get_current_view_model() == after_set_view_model
	)

	var failing_session: GameSessionType = GameSessionType.new(
		_create_state(
			40,
			ProjectStateType.Lifecycle.ACTIVE,
			true,
			6_000,
			2,
			5,
			0,
			MAX_SIGNED_INT,
			0
		),
		personality
	)
	var failing_observer: CommitObserver = CommitObserver.new(failing_session)
	failing_session.committed_result.connect(failing_observer.capture)
	var failure_state_before: GameStateType = failing_session.get_state_snapshot()
	var failure_view_model_before: DashboardViewModelType = (
		failing_session.get_current_view_model()
	)
	var failure_snapshot_before: OpponentPlanningSnapshotType = (
		failing_session.get_cached_opponent_planning_snapshot()
	)
	var failed_advance: bool = not failing_session.submit_command(
		AdvanceQuarterCommandType.new()
	).is_successful()
	var failure_preserved: bool = (
		failed_advance
		and failing_observer.count == 0
		and _game_states_equal(failing_session.get_state_snapshot(), failure_state_before)
		and failing_session.get_current_view_model() == failure_view_model_before
		and failing_session.get_last_committed_contributions().is_empty()
		and failing_session.get_last_rival_contributions().is_empty()
		and _snapshots_equal(
			failing_session.get_cached_opponent_planning_snapshot(),
			failure_snapshot_before
		)
	)
	return protected_access and retained_after_commands and failure_preserved


static func _create_personality(
	opponent_id: StringName = OpponentStateType.NORTHSTAR_LABS_ID
) -> OpponentPersonalityType:
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
		opponent_id,
		"Northstar Labs",
		candidates,
		500,
		100,
		500,
		180
	)


static func _create_state(
	player_training_units: int,
	project_lifecycle: ProjectStateType.Lifecycle,
	active_opponent: bool,
	consumer_service_allocation_bps: int = 6_000,
	consumer_pressure_rate: int = 2,
	developer_pressure_rate: int = 5,
	opponent_cumulative_training: int = 0,
	opponent_cumulative_served: int = 0,
	opponent_cumulative_unmet: int = 0
) -> GameStateType:
	var market: MarketStateType = _create_market(
		consumer_service_allocation_bps,
		consumer_pressure_rate if active_opponent or consumer_pressure_rate != 2 else 0,
		developer_pressure_rate if active_opponent or developer_pressure_rate != 5 else 0
	)
	var opponent: OpponentStateType = null
	var named_rng: NamedRngStateType = null
	if active_opponent:
		opponent = OpponentStateType.new(
			OpponentStateType.NORTHSTAR_LABS_ID,
			ComputeStateType.new(
				100,
				10,
				50,
				40,
				opponent_cumulative_training,
				opponent_cumulative_served,
				opponent_cumulative_unmet
			)
		)
		named_rng = NamedRngStateType.create_fresh_version_one(7)
	return GameStateType.new(
		CompanyStateType.new(1_000_000, 120_000, 80_000),
		ProjectStateType.new(
			PROJECT_ID,
			3,
			25_000,
			30_000,
			project_lifecycle,
			0
		),
		ComputeStateType.new(100, 10, 50, player_training_units),
		market,
		opponent,
		named_rng
	)


@warning_ignore("integer_division")
static func _create_market(
	consumer_service_allocation_bps: int,
	consumer_pressure_rate: int,
	developer_pressure_rate: int
) -> MarketStateType:
	var consumer_workload: int = (50 * consumer_service_allocation_bps) / 10_000
	var developer_workload: int = 50 - consumer_workload
	return MarketStateType.new(
		consumer_workload,
		developer_workload,
		consumer_service_allocation_bps,
		3_000,
		2_000,
		100_000,
		450_000,
		30,
		10,
		10,
		25,
		consumer_workload,
		developer_workload,
		30_000,
		90_000,
		0,
		0,
		0,
		0,
		consumer_pressure_rate,
		developer_pressure_rate
	)


static func _create_snapshot(state: GameStateType) -> OpponentPlanningSnapshotType:
	return OpponentPlanningSnapshotType.new(
		state.get_clock().get_elapsed_months(),
		state.get_market().get_consumer_player_share_bps(),
		state.get_market().get_developer_api_player_share_bps()
	)


static func _failed_quarter_preserves_all(
	engine: SimulationEngineType,
	state: GameStateType,
	snapshot: OpponentPlanningSnapshotType,
	personality: OpponentPersonalityType
) -> bool:
	var before: GameStateType = state.copy()
	var result: TickResultType = engine.advance_quarter(state, snapshot, personality)
	return (
		before != null
		and result != null
		and not result.is_successful()
		and result.get_state_snapshot() == null
		and result.get_contributions().is_empty()
		and _game_states_equal(state, before)
	)


static func _non_default_split_uses_market_rule() -> bool:
	var market: MarketStateType = _create_market(4_000, 2, 5)
	var company: CompanyStateType = CompanyStateType.new(0, 120_000, 0)
	var player_compute: ComputeStateType = ComputeStateType.new(100, 10, 50, 40)
	var opponent_compute: ComputeStateType = ComputeStateType.new(100, 10, 50, 70)
	var result = MarketSystemType.new().settle_month(
		company,
		player_compute,
		market,
		opponent_compute
	)
	if result == null or not result.is_successful():
		return false
	return (
		_sum_market_reason(
			result.get_contributions(),
			EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_OPPONENT_MARKET_PRESSURE
		) == -16
		and _sum_market_reason(
			result.get_contributions(),
			EffectContributionType.SUBJECT_DEVELOPER_API,
			EffectContributionType.REASON_OPPONENT_MARKET_PRESSURE
		) == -60
	)


static func _active_trace_matches(trace: Array[EffectContributionType]) -> bool:
	if trace.size() != 52:
		return false
	var offset: int = 0
	for month_index in 3:
		if not _effect_matches(
			trace[offset],
			EffectContributionType.SOURCE_PROJECT,
			EffectContributionType.REASON_PROJECT_MONTHLY_COST,
			PROJECT_ID,
			EffectContributionType.METRIC_CASH_CENTS,
			EffectContributionType.Unit.CENTS,
			-25_000
		):
			return false
		offset += 1
		if not _effect_matches(
			trace[offset],
			EffectContributionType.SOURCE_PROJECT,
			EffectContributionType.REASON_PROJECT_PROGRESS,
			PROJECT_ID,
			EffectContributionType.METRIC_PROJECT_PROGRESS_MONTHS,
			EffectContributionType.Unit.MONTHS,
			1
		):
			return false
		offset += 1
		if month_index == 2:
			if not _effect_matches(
				trace[offset],
				EffectContributionType.SOURCE_PROJECT,
				EffectContributionType.REASON_PROJECT_COMPLETION_REVENUE,
				PROJECT_ID,
				EffectContributionType.METRIC_MONTHLY_REVENUE_CENTS,
				EffectContributionType.Unit.CENTS,
				30_000
			):
				return false
			offset += 1
		for player_compute in [
			[EffectContributionType.REASON_TRAINING_WORK,
			EffectContributionType.METRIC_CUMULATIVE_TRAINING_COMPUTE_UNIT_MONTHS, 40],
			[EffectContributionType.REASON_INFERENCE_SERVED,
			EffectContributionType.METRIC_CUMULATIVE_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS, 50],
		]:
			if not _effect_matches(
				trace[offset],
				EffectContributionType.SOURCE_COMPUTE,
				player_compute[0],
				EffectContributionType.SUBJECT_COMPANY,
				player_compute[1],
				EffectContributionType.Unit.COMPUTE_UNIT_MONTHS,
				player_compute[2]
			):
				return false
			offset += 1
		for rival_compute in [
			[EffectContributionType.REASON_TRAINING_WORK,
			EffectContributionType.METRIC_CUMULATIVE_TRAINING_COMPUTE_UNIT_MONTHS, 70],
			[EffectContributionType.REASON_INFERENCE_SERVED,
			EffectContributionType.METRIC_CUMULATIVE_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS, 20],
			[EffectContributionType.REASON_INFERENCE_UNMET,
			EffectContributionType.METRIC_CUMULATIVE_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS, 30],
		]:
			if not _effect_matches(
				trace[offset],
				EffectContributionType.SOURCE_COMPUTE,
				rival_compute[0],
				EffectContributionType.SUBJECT_NORTHSTAR_LABS,
				rival_compute[1],
				EffectContributionType.Unit.COMPUTE_UNIT_MONTHS,
				rival_compute[2]
			):
				return false
			offset += 1
		var finance_revenue: int = [120_000, 118_710, 147_420][month_index]
		if not _effect_matches(
			trace[offset],
			EffectContributionType.SOURCE_FINANCE,
			EffectContributionType.REASON_MONTHLY_REVENUE,
			EffectContributionType.SUBJECT_COMPANY,
			EffectContributionType.METRIC_CASH_CENTS,
			EffectContributionType.Unit.CENTS,
			finance_revenue
		):
			return false
		offset += 1
		if not _effect_matches(
			trace[offset],
			EffectContributionType.SOURCE_FINANCE,
			EffectContributionType.REASON_MONTHLY_OPERATING_COST,
			EffectContributionType.SUBJECT_COMPANY,
			EffectContributionType.METRIC_CASH_CENTS,
			EffectContributionType.Unit.CENTS,
			-80_000
		):
			return false
		offset += 1
		for market_effect in [
			[EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_MARKET_SERVED,
			EffectContributionType.METRIC_CUMULATIVE_MARKET_SERVED_COMPUTE_UNIT_MONTHS,
			EffectContributionType.Unit.COMPUTE_UNIT_MONTHS, 30],
			[EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_MARKET_SHARE_CHANGE,
			EffectContributionType.METRIC_PLAYER_SHARE_BPS,
			EffectContributionType.Unit.BASIS_POINTS, 30],
			[EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_OPPONENT_MARKET_PRESSURE,
			EffectContributionType.METRIC_PLAYER_SHARE_BPS,
			EffectContributionType.Unit.BASIS_POINTS, -24],
			[EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
			EffectContributionType.METRIC_MARKET_MONTHLY_REVENUE_CENTS,
			EffectContributionType.Unit.CENTS, 60],
			[EffectContributionType.SUBJECT_DEVELOPER_API,
			EffectContributionType.REASON_MARKET_SERVED,
			EffectContributionType.METRIC_CUMULATIVE_MARKET_SERVED_COMPUTE_UNIT_MONTHS,
			EffectContributionType.Unit.COMPUTE_UNIT_MONTHS, 20],
			[EffectContributionType.SUBJECT_DEVELOPER_API,
			EffectContributionType.REASON_MARKET_SHARE_CHANGE,
			EffectContributionType.METRIC_PLAYER_SHARE_BPS,
			EffectContributionType.Unit.BASIS_POINTS, 10],
			[EffectContributionType.SUBJECT_DEVELOPER_API,
			EffectContributionType.REASON_OPPONENT_MARKET_PRESSURE,
			EffectContributionType.METRIC_PLAYER_SHARE_BPS,
			EffectContributionType.Unit.BASIS_POINTS, -40],
			[EffectContributionType.SUBJECT_DEVELOPER_API,
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
			EffectContributionType.METRIC_MARKET_MONTHLY_REVENUE_CENTS,
			EffectContributionType.Unit.CENTS, -1_350],
		]:
			if not _effect_matches(
				trace[offset],
				EffectContributionType.SOURCE_MARKET,
				market_effect[1],
				market_effect[0],
				market_effect[2],
				market_effect[3],
				market_effect[4]
			):
				return false
			offset += 1
	return offset == 52


static func _legacy_trace_order_matches(
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
	return true


static func _legacy_state_matches(
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
	return (
		state != null
		and state.get_clock().get_elapsed_months() == 3
		and state.get_company().get_cash_cents() == cash_cents
		and state.get_company().get_monthly_revenue_cents() == monthly_revenue_cents
		and state.get_project().get_lifecycle() == ProjectStateType.Lifecycle.COMPLETED
		and state.get_project().get_progress_months() == 3
		and state.get_compute().get_training_allocation_units_per_month()
			== training_units
		and state.get_market().get_consumer_player_share_bps() == consumer_share_bps
		and state.get_market().get_developer_api_player_share_bps() == developer_share_bps
		and state.get_market().get_consumer_current_market_revenue_cents()
			== consumer_revenue_cents
		and state.get_market().get_developer_api_current_market_revenue_cents()
			== developer_revenue_cents
		and state.get_market().get_consumer_cumulative_served_compute_unit_months()
			== consumer_served
		and state.get_market().get_consumer_cumulative_unmet_compute_unit_months()
			== consumer_unmet
		and state.get_market().get_developer_api_cumulative_served_compute_unit_months()
			== developer_served
		and state.get_market().get_developer_api_cumulative_unmet_compute_unit_months()
			== developer_unmet
		and state.get_opponent().get_opponent_id() == &""
		and _compute_fields(state.get_opponent().get_compute()) == [0, 0, 0, 0, 0, 0, 0]
		and state.get_named_rng().is_canonical_inactive()
	)


static func _rival_slice_matches(trace: Array[EffectContributionType]) -> bool:
	if trace.size() != 15:
		return false
	var index: int = 0
	for _month_index in 3:
		for expected in [
			[EffectContributionType.SOURCE_COMPUTE,
			EffectContributionType.REASON_TRAINING_WORK,
			EffectContributionType.SUBJECT_NORTHSTAR_LABS, 70],
			[EffectContributionType.SOURCE_COMPUTE,
			EffectContributionType.REASON_INFERENCE_SERVED,
			EffectContributionType.SUBJECT_NORTHSTAR_LABS, 20],
			[EffectContributionType.SOURCE_COMPUTE,
			EffectContributionType.REASON_INFERENCE_UNMET,
			EffectContributionType.SUBJECT_NORTHSTAR_LABS, 30],
			[EffectContributionType.SOURCE_MARKET,
			EffectContributionType.REASON_OPPONENT_MARKET_PRESSURE,
			EffectContributionType.SUBJECT_CONSUMER, -24],
			[EffectContributionType.SOURCE_MARKET,
			EffectContributionType.REASON_OPPONENT_MARKET_PRESSURE,
			EffectContributionType.SUBJECT_DEVELOPER_API, -40],
		]:
			if (
				trace[index].get_source_key() != expected[0]
				or trace[index].get_reason_key() != expected[1]
				or trace[index].get_subject_key() != expected[2]
				or trace[index].get_delta() != expected[3]
			):
				return false
			index += 1
	return true


static func _trace_has_no_rival_effect(trace: Array[EffectContributionType]) -> bool:
	for contribution in trace:
		if (
			contribution.get_subject_key() == EffectContributionType.SUBJECT_NORTHSTAR_LABS
			or contribution.get_reason_key()
				== EffectContributionType.REASON_OPPONENT_MARKET_PRESSURE
		):
			return false
	return true


static func _initial_rival_view_model_matches(
	view_model: DashboardViewModelType
) -> bool:
	return (
		view_model.get_rival_signal_text()
			== "Northstar Labs signal: 70 training / 20 inference"
		and view_model.get_rival_reason_text() == "Why: Close training gap"
		and view_model.get_rival_utility_text()
			== "Utility: 688 = 680 + 8 seeded noise"
		and view_model.get_rival_last_action_text() == "Last action: —"
		and view_model.get_rival_quarter_text() == "Quarter: —"
		and view_model.get_rival_market_pressure_text() == "Market pressure: —"
	)


static func _committed_rival_view_model_matches(
	view_model: DashboardViewModelType
) -> bool:
	return (
		view_model.get_rival_signal_text()
			== "Next signal: 40 training / 50 inference — Defend market position"
		and view_model.get_rival_reason_text() == "Why: Defend market position"
		and view_model.get_rival_utility_text()
			== "Utility: 553 = 549 + 4 seeded noise"
		and view_model.get_rival_last_action_text()
			== "Last action: 70 training / 20 inference"
		and view_model.get_rival_quarter_text()
			== "Quarter: +210 training; inference 60/150; unmet 90"
		and view_model.get_rival_market_pressure_text()
			== "Market pressure: Consumer -72 bps; Developer/API -120 bps"
	)


static func _rival_view_model_is_empty(view_model: DashboardViewModelType) -> bool:
	return (
		view_model.get_rival_signal_text().is_empty()
		and view_model.get_rival_reason_text().is_empty()
		and view_model.get_rival_utility_text().is_empty()
		and view_model.get_rival_last_action_text().is_empty()
		and view_model.get_rival_quarter_text().is_empty()
		and view_model.get_rival_market_pressure_text().is_empty()
	)


static func _snapshots_equal(
	first: OpponentPlanningSnapshotType,
	second: OpponentPlanningSnapshotType
) -> bool:
	return (
		first != null
		and second != null
		and first.get_elapsed_months() == second.get_elapsed_months()
		and first.get_consumer_player_share_bps()
			== second.get_consumer_player_share_bps()
		and first.get_developer_api_player_share_bps()
			== second.get_developer_api_player_share_bps()
	)


static func _game_states_equal(first: GameStateType, second: GameStateType) -> bool:
	if first == null or second == null:
		return first == second
	return (
		first.get_clock().get_elapsed_months() == second.get_clock().get_elapsed_months()
		and first.get_company().get_cash_cents() == second.get_company().get_cash_cents()
		and first.get_company().get_monthly_revenue_cents()
			== second.get_company().get_monthly_revenue_cents()
		and first.get_company().get_monthly_operating_cost_cents()
			== second.get_company().get_monthly_operating_cost_cents()
		and first.get_project().get_project_id() == second.get_project().get_project_id()
		and first.get_project().get_lifecycle() == second.get_project().get_lifecycle()
		and first.get_project().get_required_months()
			== second.get_project().get_required_months()
		and first.get_project().get_progress_months()
			== second.get_project().get_progress_months()
		and first.get_project().get_monthly_cost_cents()
			== second.get_project().get_monthly_cost_cents()
		and first.get_project().get_completion_monthly_revenue_delta_cents()
			== second.get_project().get_completion_monthly_revenue_delta_cents()
		and _compute_fields(first.get_compute()) == _compute_fields(second.get_compute())
		and _market_fields(first.get_market()) == _market_fields(second.get_market())
		and _opponent_fields(first.get_opponent()) == _opponent_fields(second.get_opponent())
		and _rng_fields(first.get_named_rng()) == _rng_fields(second.get_named_rng())
	)


static func _compute_fields(compute: ComputeStateType) -> Array[int]:
	return [
		compute.get_total_units_per_month(),
		compute.get_reserve_units_per_month(),
		compute.get_inference_workload_units_per_month(),
		compute.get_training_allocation_units_per_month(),
		compute.get_cumulative_training_compute_unit_months(),
		compute.get_cumulative_served_inference_compute_unit_months(),
		compute.get_cumulative_unmet_inference_compute_unit_months(),
	]


static func _market_fields(market: MarketStateType) -> Array[int]:
	return [
		market.get_consumer_workload_units_per_month(),
		market.get_developer_api_workload_units_per_month(),
		market.get_consumer_service_allocation_bps(),
		market.get_consumer_player_share_bps(),
		market.get_developer_api_player_share_bps(),
		market.get_consumer_addressable_monthly_revenue_cents(),
		market.get_developer_api_addressable_monthly_revenue_cents(),
		market.get_consumer_full_service_growth_bps(),
		market.get_developer_api_full_service_growth_bps(),
		market.get_consumer_unmet_penalty_bps_per_unit(),
		market.get_developer_api_unmet_penalty_bps_per_unit(),
		market.get_consumer_current_served_units_per_month(),
		market.get_developer_api_current_served_units_per_month(),
		market.get_consumer_current_market_revenue_cents(),
		market.get_developer_api_current_market_revenue_cents(),
		market.get_consumer_cumulative_served_compute_unit_months(),
		market.get_consumer_cumulative_unmet_compute_unit_months(),
		market.get_developer_api_cumulative_served_compute_unit_months(),
		market.get_developer_api_cumulative_unmet_compute_unit_months(),
		market.get_consumer_opponent_pressure_bps_per_served_unit(),
		market.get_developer_api_opponent_pressure_bps_per_served_unit(),
	]


static func _opponent_fields(opponent: OpponentStateType) -> Array:
	return [
		opponent.get_opponent_id(),
		_compute_fields(opponent.get_compute()),
		opponent.get_last_candidate_key(),
		opponent.get_last_training_units_per_month(),
		opponent.get_last_reason_key(),
		opponent.get_last_base_utility_points(),
		opponent.get_last_noise_points(),
		opponent.get_last_total_utility_points(),
	]


static func _rng_fields(rng_state: NamedRngStateType) -> Array[int]:
	return [
		rng_state.get_master_seed(),
		rng_state.get_algorithm_version(),
		rng_state.get_ai_stream_state(),
		rng_state.get_events_stream_state(),
		rng_state.get_market_stream_state(),
	]


static func _effect_matches(
	effect: EffectContributionType,
	source: StringName,
	reason: StringName,
	subject: StringName,
	metric: StringName,
	unit: int,
	delta: int
) -> bool:
	return (
		effect != null
		and effect.get_source_key() == source
		and effect.get_reason_key() == reason
		and effect.get_subject_key() == subject
		and effect.get_metric_key() == metric
		and effect.get_unit() == unit
		and effect.get_delta() == delta
	)


static func _sum_market_reason(
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
